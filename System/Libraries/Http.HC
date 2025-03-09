#define HTTP_TMP_DIRECTORY "B:/Tmp"
#define HTTP_CACHE_DIRECTORY "B:/Tmp/Cache"
#define HTTP_FETCH_BUFFER_SIZE 1024 << 15

#define SEDECIM_USER_AGENT_STRING "Mozilla/5.0 (compatible; Sedecim/1.0; TempleOS) (KHTML, like Gecko)"

class @http_buffer
{
    I64 length;
    U8* data;
};

class @http_status
{
    U8* protocol;
    I64 code;
    U8* text;
};

class @http_response
{
    I64 state;
    TlsSocket* s;
    @http_status status;
    JsonObject* headers;
    @http_buffer body;
    Bool headers_parsed;
};

class @http_url
{
    U8* scheme;
    U8* host;
    I64 port;
    U8* path;
    U8* query;
    U8* fragment;
};

class @http_request
{
    @http_url* url;
    U8* buf;
    U8* data;
    I64 type;
    JsonObject* headers;
    @http_response* response;
};

#define HttpResponse @http_response
#define HttpUrl @http_url

#define HTTP_FETCH_BUFFER_SIZE 16777216

#define HTTP_PARSE_SCHEME 0
#define HTTP_PARSE_SCHEME_FS 1
#define HTTP_PARSE_HOST 2
#define HTTP_PARSE_PORT 3
#define HTTP_PARSE_PATH 4
#define HTTP_PARSE_QUERY 5
#define HTTP_PARSE_FRAGMENT 6

#define HTTP_MIN_REQUEST_BUFFER_SIZE 16384
#define HTTP_PARSE_URL_FIFO_SIZE 1024

#define HTTP_REQ_GET 0
#define HTTP_REQ_HEAD 1
#define HTTP_REQ_POST 2
#define HTTP_REQ_PUT 3

#define HTTP_STATE_UNSENT 0
#define HTTP_STATE_OPENED 1
#define HTTP_STATE_HEADERS_RECEIVED 2
#define HTTP_STATE_LOADING 3
#define HTTP_STATE_DONE 4

U8* @http_string_from_fifo(CFifoU8* f)
{
    U8 ch;
    I64 i = 0;
    U8* str = CAlloc(FifoU8Cnt(f) + 1, slon_mem_task);
    while (FifoU8Cnt(f)) {
        FifoU8Rem(f, &ch);
        str[i] = ch;
        i++;
    }
    FifoU8Flush(f);
    return str;
}

U0 @http_free_url(@http_url* url)
{
    if (!url)
        return;
    if (url->scheme)
        Free(url->scheme);
    if (url->host)
        Free(url->host);
    if (url->path)
        Free(url->path);
    if (url->query)
        Free(url->query);
    if (url->fragment)
        Free(url->fragment);
    Free(url);
}

U0 @http_free_response(@http_response* resp)
{
    if (!resp)
        return;
    // FIXME: Free response headers JSON object
    Free(resp);
}

@http_url* @http_parse_url(U8* str)
{
    if (!str)
        return NULL;
    U8* buf = NULL;
    U8 hex[3];
    I64 i = 0;
    I64 state = HTTP_PARSE_SCHEME;
    CFifoU8* consume_fifo = FifoU8New(HTTP_PARSE_URL_FIFO_SIZE, slon_mem_task);
    @http_url* url = CAlloc(sizeof(@http_url), slon_mem_task);
    while (1) {
        switch (str[i]) {
        case 0:
            switch (state) {
            case HTTP_PARSE_HOST:
                url->host = @http_string_from_fifo(consume_fifo);
                url->path = StrNew("/", slon_mem_task);
                goto done_parsing_url;
                break;
            case HTTP_PARSE_PORT:
                buf = @http_string_from_fifo(consume_fifo);
                url->port = Str2I64(buf);
                Free(buf);
                url->path = StrNew("/", slon_mem_task);
                goto done_parsing_url;
                break;
            case HTTP_PARSE_PATH:
                url->path = @http_string_from_fifo(consume_fifo);
                goto done_parsing_url;
                break;
            case HTTP_PARSE_QUERY:
                url->query = @http_string_from_fifo(consume_fifo);
                goto done_parsing_url;
                break;
            case HTTP_PARSE_FRAGMENT:
                url->fragment = @http_string_from_fifo(consume_fifo);
                goto done_parsing_url;
                break;
            default:
                goto done_parsing_url;
                break;
            }
            break;
        case '#':
            switch (state) {
            case HTTP_PARSE_PATH:
                url->path = @http_string_from_fifo(consume_fifo);
                FifoU8Ins(consume_fifo, str[i]);
                state = HTTP_PARSE_FRAGMENT;
                break;
            case HTTP_PARSE_QUERY:
                url->query = @http_string_from_fifo(consume_fifo);
                FifoU8Ins(consume_fifo, str[i]);
                state = HTTP_PARSE_FRAGMENT;
                break;
            }
            break;
        case '?':
            switch (state) {
            case HTTP_PARSE_PATH:
                url->path = @http_string_from_fifo(consume_fifo);
                FifoU8Ins(consume_fifo, str[i]);
                state = HTTP_PARSE_QUERY;
                break;
            }
            break;
        case '/':
            switch (state) {
            case HTTP_PARSE_SCHEME:
                state = HTTP_PARSE_SCHEME_FS;
                goto keep_consuming_url_chars;
                break;
            case HTTP_PARSE_SCHEME_FS:
                FifoU8Ins(consume_fifo, str[i]);
                url->scheme = @http_string_from_fifo(consume_fifo);
                if (!StrCmp(url->scheme, "http://"))
                    url->port = 80;
                if (!StrCmp(url->scheme, "https://"))
                    url->port = 443;
                state = HTTP_PARSE_HOST;
                break;
            case HTTP_PARSE_HOST:
                url->host = @http_string_from_fifo(consume_fifo);
                FifoU8Ins(consume_fifo, str[i]);
                state = HTTP_PARSE_PATH;
                break;
            case HTTP_PARSE_PORT:
                buf = @http_string_from_fifo(consume_fifo);
                url->port = Str2I64(buf);
                Free(buf);
                FifoU8Ins(consume_fifo, str[i]);
                state = HTTP_PARSE_PATH;
                break;
            case HTTP_PARSE_PATH:
                goto keep_consuming_url_chars;
                break;
            }
            break;
        case ':':
            switch (state) {
            case HTTP_PARSE_SCHEME:
            case HTTP_PARSE_PATH:
            case HTTP_PARSE_QUERY:
            case HTTP_PARSE_FRAGMENT:
                goto keep_consuming_url_chars;
                break;
            case HTTP_PARSE_HOST:
                url->host = @http_string_from_fifo(consume_fifo);
                state = HTTP_PARSE_PORT;
                break;
            }
            break;
        default:
        keep_consuming_url_chars:
            switch (state) {
            case HTTP_PARSE_PATH:
            case HTTP_PARSE_QUERY:
                switch (str[i]) {
                case '0' ... '9':
                case 'A' ... 'Z':
                case 'a' ... 'z':
                case '?':
                case '&':
                case '/':
                case '=':
                // !'()*-._~
                case '!':
                case '\'':
                case '(':
                case ')':
                case '*':
                case '-':
                case '.':
                case '_':
                case '~':
                case '%':
                    FifoU8Ins(consume_fifo, str[i]);
                    break;
                default:
                    FifoU8Ins(consume_fifo, '%');
                    StrPrint(hex, "%02X", str[i]);
                    FifoU8Ins(consume_fifo, hex[0]);
                    FifoU8Ins(consume_fifo, hex[1]);
                    break;
                }
                break;
            default:
                FifoU8Ins(consume_fifo, str[i]);
                break;
            }
            break;
        }
        i++;
    }
done_parsing_url:
    FifoU8Flush(consume_fifo);
    FifoU8Del(consume_fifo);
    return url;
}

U0 @http_parse_response_headers(@http_response* resp, U8* buffer, I64 length)
{
    if (!resp || !buffer || !length)
        return;
    U64 response_data_ptr = StrFind("\r\n\r\n", buffer);
    if (!response_data_ptr)
        return;
    resp->body.data = response_data_ptr + 4;
    resp->body.data[-4] = NULL;
    JsonObject* headers = Json.CreateObject(slon_mem_task);
    U8** lines = NULL;
    I64 lines_count = 0;
    I64 i;
    I64 j;
    U8* key_ptr = NULL;
    U8* value_ptr = NULL;
    lines = String.Split(buffer, '\n', &lines_count);

    U8* resp_protocol = lines[0];
    U8* resp_status_code = StrFind(" ", resp_protocol) + 1;
    U8* resp_text = StrFind(" ", resp_status_code + 1);
    (*StrFind(" ", resp_protocol)) = NULL;
    (*StrFind(" ", resp_status_code)) = NULL;

    resp->status.protocol = StrNew(resp_protocol, slon_mem_task);
    resp->status.code = Str2I64(resp_status_code);
    resp->status.text = StrNew(resp_text, slon_mem_task);

    for (i = 1; i < lines_count; i++) {
        for (j = 0; j < StrLen(lines[i]); j++) {
            if (lines[i][j] == ':' && lines[i][j + 1] == ' ') {
                lines[i][j] = NULL;
                key_ptr = lines[i];
                value_ptr = lines[i] + j + 2;
                (*StrFind("\r", value_ptr)) = NULL;
                headers->set(key_ptr, value_ptr, JSON_STRING);
                goto @http_next_header_line;
            }
        }
        @http_next_header_line:
    }
    resp->headers = headers;
    resp->headers_parsed = TRUE;
}

Bool @http_detect_response_headers(U8* buf, I64 len)
{
    if (len < 4)
        return FALSE;
    I64 i;
    for (i = 0; i < len - 4; i++) {
        if (!MemCmp(buf + i, "\r\n\r\n", 4))
            return TRUE;
    }
    return FALSE;
}

I64 @http_req(@http_request* req)
{
    if (!req)
        return NULL;
    if (!req->url || !req->buf || !req->response)
        return NULL;
    if (!req->url->scheme || !req->url->host || !req->url->path)
        return NULL;
    if (req->type == HTTP_REQ_POST && !req->data)
        return NULL;
    if (req->type == HTTP_REQ_PUT && !req->data)
        return NULL;

    @http_response* resp = req->response;

    U8* buf = NULL;
    U8* headers_buf = "";
    I64 cnt = 1;
    I64 len = NULL;

    buf = CAlloc(HTTP_MIN_REQUEST_BUFFER_SIZE, slon_mem_task);
    if (req->headers) {
        headers_buf = CAlloc(HTTP_MIN_REQUEST_BUFFER_SIZE, slon_mem_task);
        JsonKey* key = req->headers->keys;
        while (key) {
            StrPrint(headers_buf + StrLen(headers_buf), "%s: %s\r\n", key->name, key->value);
            key = key->next;
        }
    }

    switch (req->type) {
    case HTTP_REQ_GET:
        StrPrint(buf,
            "GET %s%s HTTP/1.0\r\n"
            "Host: %s\r\n"
            "%s"
            "User-Agent: " SEDECIM_USER_AGENT_STRING
            "\r\n\r\n",
            req->url->path, req->url->query, req->url->host, headers_buf);
        break;
    case HTTP_REQ_HEAD:
        StrPrint(buf,
            "HEAD %s%s HTTP/1.0\r\n"
            "Host: %s\r\n"
            "%s"
            "User-Agent: " SEDECIM_USER_AGENT_STRING
            "\r\n\r\n",
            req->url->path, req->url->query, req->url->host, headers_buf);
        break;
    case HTTP_REQ_POST:
        StrPrint(buf,
            "POST %s%s HTTP/1.0\r\n"
            "Host: %s\r\n"
            "%s"
            "User-Agent: " SEDECIM_USER_AGENT_STRING
            "\r\n"
            "Content-Length: %d\r\n\r\n",
            req->url->path, req->url->query, req->url->host, headers_buf,
            StrLen(req->data));
        StrPrint(buf + StrLen(buf), req->data);
        break;
    case HTTP_REQ_PUT:
        StrPrint(buf,
            "PUT %s%s HTTP/1.0\r\n"
            "Host: %s\r\n"
            "%s"
            "User-Agent: " SEDECIM_USER_AGENT_STRING
            "\r\n"
            "Content-Length: %d\r\n\r\n",
            req->url->path, req->url->query, req->url->host, headers_buf,
            StrLen(req->data));
        StrPrint(buf + StrLen(buf), req->data);
        break;
    }

    TlsSocket* s = NULL;
    resp->s = NULL;

    if (!StrCmp(req->url->scheme, "http://")) {
        s = @tcp_socket_create(req->url->host, req->url->port);
        resp->s = s;
        while (s->state != TCP_SOCKET_STATE_ESTABLISHED)
            Sleep(1);
    }

    if (!StrCmp(req->url->scheme, "https://")) {
        s = @tls_socket_create(req->url->host, req->url->port);
        resp->s = s;
        while (!@tls_established(s->ctx))
            Sleep(1);
    }

    resp->state = HTTP_STATE_OPENED;
    s->send(buf, StrLen(buf));
    while (cnt || s->state != TCP_SOCKET_STATE_CLOSED) {
        cnt = s->receive(req->buf + len, 1024);
        len += cnt;
        switch (resp->state) {
        case HTTP_STATE_LOADING:
            resp->body.length += cnt;
            break;
        case HTTP_STATE_HEADERS_RECEIVED:
            resp->body.length = (req->buf + len) - resp->body.data;
            resp->state = HTTP_STATE_LOADING;
            break;
        case HTTP_STATE_OPENED:
            if (@http_detect_response_headers(req->buf, len)) {
                @http_parse_response_headers(resp, req->buf, len);
                resp->state = HTTP_STATE_HEADERS_RECEIVED;
            }
            break;
        }
        Sleep(1);
    }
    if (!resp->headers_parsed)
        @http_parse_response_headers(resp, req->buf, len);
    resp->state = HTTP_STATE_DONE;
    req->buf[len] = NULL;
    Free(buf);
    if (StrLen(headers_buf) > 0) {
        Free(headers_buf);
    }
    s->close();
    resp->s = NULL;
    Free(req);
    return len;
}

Bool @http_scheme_is_https(@http_url* url)
{
    if (!url || !url->scheme)
        return FALSE;
    return !MemCmp(url->scheme, "https", 5);
}

@http_response* @http_get(@http_url* url, U8* buf, U64 return_req = NULL, JsonObject* headers = NULL)
{
    @http_response* resp = CAlloc(sizeof(@http_response), slon_mem_task);
    @http_request* req = CAlloc(sizeof(@http_request), slon_mem_task);
    if (return_req)
        MemCpy(return_req, &req, sizeof(U64));
    req->url = url;
    req->buf = buf;
    req->type = HTTP_REQ_GET;
    req->headers = headers;
    req->response = resp;
    Spawn(&@http_req, req, "HTTPGetRequest");
    return resp;
}

@http_response* @http_head(@http_url* url, U8* buf, JsonObject* headers = NULL)
{
    @http_response* resp = CAlloc(sizeof(@http_response), slon_mem_task);
    @http_request* req = CAlloc(sizeof(@http_request), slon_mem_task);
    req->url = url;
    req->buf = buf;
    req->type = HTTP_REQ_HEAD;
    req->headers = headers;
    req->response = resp;
    Spawn(&@http_req, req, "HTTPHeadRequest");
    return resp;
}

@http_response* @http_post(@http_url* url, U8* buf, U8* data, JsonObject* headers = NULL)
{
    @http_response* resp = CAlloc(sizeof(@http_response), slon_mem_task);
    @http_request* req = CAlloc(sizeof(@http_request), slon_mem_task);
    req->url = url;
    req->buf = buf;
    req->type = HTTP_REQ_POST;
    req->headers = headers;
    req->data = data;
    req->response = resp;
    Spawn(&@http_req, req, "HTTPPostRequest");
    return resp;
}

@http_response* @http_put(@http_url* url, U8* buf, U8* data, JsonObject* headers = NULL)
{
    @http_response* resp = CAlloc(sizeof(@http_response), slon_mem_task);
    @http_request* req = CAlloc(sizeof(@http_request), slon_mem_task);
    req->url = url;
    req->buf = buf;
    req->type = HTTP_REQ_PUT;
    req->headers = headers;
    req->data = data;
    req->response = resp;
    Spawn(&@http_req, req, "HTTPPutRequest");
    return resp;
}

class @http
{
    @http_response* (*Get)(@http_url* url, U8* buf, U64* req = NULL, JsonObject* headers = NULL);
    @http_response* (*Head)(@http_url* url, U8* buf, JsonObject* headers = NULL);
    @http_response* (*Post)(@http_url* url, U8* buf, U8* data, JsonObject* headers = NULL);
    @http_response* (*Put)(@http_url* url, U8* buf, U8* data, JsonObject* headers = NULL);
};

@http Http;

Http.Get = &@http_get;
Http.Head = &@http_head;
Http.Post = &@http_post;
Http.Put = &@http_put;

Bool @http_is_resource_cached(U8* src, U8* cache_directory = HTTP_CACHE_DIRECTORY)
{
    U8 buf[512];
    U8* src_md5 = md5_string(src, StrLen(src));
    StrCpy(buf, cache_directory);
    StrPrint(buf + StrLen(buf), "/%s", src_md5);
    Free(src_md5);
    return FileFind(buf);
}

U0 @http_cache_resource(U8* src, U8* data, I64 size, U8* cache_directory = HTTP_CACHE_DIRECTORY)
{
    U8 buf[512];
    U8* src_md5 = md5_string(src, StrLen(src));
    StrCpy(buf, cache_directory);
    StrPrint(buf + StrLen(buf), "/%s", src_md5);
    Free(src_md5);
    FileWrite(buf, data, size);
}

U8* @http_get_cached_resource_filename(U8* src, U8* cache_directory = HTTP_CACHE_DIRECTORY)
{
    U8* buf = CAlloc(512, slon_mem_task);
    U8* src_md5 = md5_string(src, StrLen(src));
    StrCpy(buf, cache_directory);
    StrPrint(buf + StrLen(buf), "/%s", src_md5);
    Free(src_md5);
    return buf;
}

U0 @http_init_tmp_and_cache_directories()
{
    if (!FileFind(HTTP_TMP_DIRECTORY))
        DirMk(HTTP_TMP_DIRECTORY);
    if (!FileFind(HTTP_CACHE_DIRECTORY))
        DirMk(HTTP_CACHE_DIRECTORY);
}

@http_response* fetch(U8* url_string, U8* fetch_buffer)
{
    if (!url_string || !fetch_buffer)
        return NULL;
    HttpUrl* url = @http_parse_url(url_string);
    if (!url)
        return NULL;
    @http_response* resp = Http.Get(url, fetch_buffer);
    while (resp->state != HTTP_STATE_DONE)
        Sleep(1);
    return resp;
}

I64 curl(U8* url_string)
{
    if (!url_string)
        return 0;
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    @http_response* resp = fetch(url_string, fetch_buffer);
    if (!resp)
        return 0;
    if (resp->body.length) {
        U8* buf = resp->body.data;
        while (*buf) {
            if (*buf == '\d')
                "\d\d";
            else
                "%c", *buf;
            ++buf;
        }
        "\n";
    }
    Free(fetch_buffer);
    return resp->body.length;
}

I64 download(U8* path, U8* url_string)
{
    if (!path || !url_string)
        return 0;
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    @http_response* resp = fetch(url_string, fetch_buffer);
    if (!resp)
        return 0;
    if (resp->body.length) {
        FileWrite(path, resp->body.data, resp->body.length);
    }
    Free(fetch_buffer);
    return resp->body.length;
}

@http_init_tmp_and_cache_directories;
