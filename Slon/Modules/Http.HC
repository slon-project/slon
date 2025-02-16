#define SLON_HTTP_BUFFER_SIZE 1048576
#define SLON_HTTP_VERB_DELETE 1
#define SLON_HTTP_VERB_GET 2
#define SLON_HTTP_VERB_OPTIONS 3
#define SLON_HTTP_VERB_PATCH 4
#define SLON_HTTP_VERB_POST 5

#define SLON_MULTIPART_PARSER_CONSUME_BOUNDARY 0
#define SLON_MULTIPART_PARSER_CONSUME_CONTENT_DISPOSITION 1
#define SLON_MULTIPART_PARSER_CONSUME_CONTENT 2
#define SLON_MULTIPART_PARSER_DONE 3

#define SLON_SCRATCH_BUFFER_AND_REQUEST_JSON \
    U8 scratch_buffer[256];                  \
    JsonObject* request_json = @slon_http_request_json(session);

#define SLON_DEBUG_PRINT_REQUEST_JSON                            \
    JsonObject* request_json = @slon_http_request_json(session); \
    U8* request_json_str = Json.Stringify(request_json);         \
    AdamLog("request_json: %s\n", request_json_str);             \
    Free(request_json_str);

JsonObject* SLON_HTTP_STATUS_CODES = Json.ParseFile("M:/Slon/Settings/status_codes.json");

class SlonHttpBuffer {
    U8* data;
    I64 size;
    I64 capacity;
};

class SlonHttpRequest {
    SlonHttpBuffer* buffer;
    JsonObject* headers;
    JsonObject* json;
    U8* data;
    I64 size;
    U8* verb;
    U8* raw_path;
    U8* path;
    Bool headers_have_been_parsed;
};

class SlonHttpResponse {
    SlonHttpBuffer* buffer;
    JsonObject* headers;
    U8* data;
    I64 size;
    I64 status_code;
};

class SlonHttpSession {
    U64 s;
    SlonHttpRequest* request;
    SlonHttpResponse* response;
    I64 bytes_used;
    JsonObject* auth;
};

U64 @slon_calloc(SlonHttpSession* session, I64 size)
{
    if (!session || !size)
        return NULL;
    U64 res = CAlloc(size, adam_task);
    session->bytes_used += MSize2(res);
    // AdamLog("@slon_calloc: requested %d, total used: %d\n", MSize2(res), session->bytes_used);
    return res;
}

U0 @slon_free(SlonHttpSession* session, U64 ptr)
{
    if (!session || !ptr)
        return;
    session->bytes_used -= MSize2(ptr);
    // AdamLog("@slon_free: freed %d, total used: %d\n", MSize2(ptr), session->bytes_used);
    Free(ptr);
}

U64 @slon_malloc(SlonHttpSession* session, I64 size)
{
    if (!session || !size)
        return NULL;
    U64 res = MAlloc(size, adam_task);
    session->bytes_used += MSize2(res);
    // AdamLog("@slon_malloc: requested %d, total used: %d\n", MSize2(res), session->bytes_used);
    return res;
}

U8* @slon_strnew(SlonHttpSession* session, U8* str)
{
    if (!session || !str)
        return NULL;
    U8* new = StrNew(str, adam_task);
    session->bytes_used += MSize2(new);
    // AdamLog("@slon_strnew: requested %d, total used: %d\n", MSize2(new), session->bytes_used);
    // AdamLog("@slon_strnew: %s\n", new);
    return new;
}

U8* @slon_http_decode_urlencoded_string(SlonHttpSession* session, U8* str)
{
    if (!StrFind("%", str) && !StrFind("+", str)) {
        return @slon_strnew(session, str);
    }
    U8* decoded_string = @slon_calloc(session, StrLen(str));
    I64 i = 0;
    I64 j;
    U32 code_point;
    while (i < StrLen(str)) {
        if (str[i] == '%') {
            code_point = 0;
            for (j = 2; j > 0; j--) {
                if (str[i + j] >= '0' && str[i + j] <= '9')
                    code_point += (@t(j == 1, 16, 1) * (str[i + j] - '0'));
                if (str[i + j] >= 'A' && str[i + j] <= 'F')
                    code_point += (@t(j == 1, 16, 1) * (10 + (str[i + j] - 'A')));
                if (str[i + j] >= 'a' && str[i + j] <= 'f')
                    code_point += (@t(j == 1, 16, 1) * (10 + (str[i + j] - 'a')));
            }
            String.Append(decoded_string, "%c", code_point);
            i += 3;
        } else if (str[i] == '+') {
            String.Append(decoded_string, " ");
            i++;
        } else {
            String.Append(decoded_string, "%c", str[i]);
            i++;
        }
    }
    return decoded_string;
}

JsonObject* @slon_http_request_json(SlonHttpSession* session)
{
    if (!session->request->json)
        return SLON_EMPTY_JSON_OBJECT;
    return session->request->json;
}

U0 @slon_http_set_header(SlonHttpSession* session, U8* key, U8* value)
{
    Json.Set(session->response->headers, key, value, JSON_STRING);
}

U0 @slon_http_set_content_type(SlonHttpSession* session, U8* value)
{
    @slon_http_set_header(session, "content-type", value);
}

U0 @slon_http_set_status_code(SlonHttpSession* session, I64 status_code)
{
    session->response->status_code = status_code;
}

U0 @slon_http_send_ap_json(SlonHttpSession* session, U64 json)
{
    // a stringified copy of "json" is created, a strnew is sent, we clean up stringified copy, sender cleans up "json"
    @slon_http_set_status_code(session, 200);
    @slon_http_set_content_type(session, "application/activity+json; charset=utf-8");
    U8* json_string = Json.Stringify(json);
    session->response->data = @slon_strnew(session, json_string);
    session->response->size = StrLen(session->response->data);
    Free(json_string);
}

U0 @slon_http_send_json(SlonHttpSession* session, U64 json)
{
    // a stringified copy of "json" is created, a strnew is sent, we clean up stringified copy, sender cleans up "json"
    @slon_http_set_status_code(session, 200);
    @slon_http_set_content_type(session, "application/json; charset=utf-8");
    U8* json_string = Json.Stringify(json);
    session->response->data = @slon_strnew(session, json_string);
    session->response->size = StrLen(session->response->data);
    Free(json_string);
}

U0 @slon_http_send_string(SlonHttpSession* session, U8* str)
{
    // a strnew of "str" is sent, sender cleans up "str"
    @slon_http_set_status_code(session, 200);
    session->response->data = @slon_strnew(session, str);
    session->response->size = StrLen(str);
}

U0 @slon_http_send(SlonHttpSession* session, U64 data, I64 size)
{
    // a malloc copy of "data" is sent, sender cleans up "data"
    @slon_http_set_status_code(session, 200);
    U8* data_new = @slon_malloc(session, size);
    MemCpy(data_new, data, size);
    session->response->data = data_new;
    session->response->size = size;
}

U0 @slon_http_send_file(SlonHttpSession* session, U8* path)
{
    if (!session || !path)
        return;
    if (!FileFind(path))
        return;
    I64 size = 0;
    U8* data = FileRead(path, &size);
    @slon_http_send(session, data, size);
    Free(data);
}

U0 @slon_http_send_html_file(SlonHttpSession* session, U8* path)
{
    @slon_http_set_content_type(session, "text/html");
    @slon_http_send_file(session, path);
}

U0 @slon_http_send_json_file(SlonHttpSession* session, U8* path, U8* content_type = "application/json; charset=utf-8")
{
    @slon_http_set_content_type(session, content_type);
    @slon_http_send_file(session, path);
}

U8* @slon_http_request_path(SlonHttpSession* session)
{
    return session->request->path;
}

I64 @slon_http_request_verb(SlonHttpSession* session)
{
    if (!StrCmp(session->request->verb, "DELETE"))
        return SLON_HTTP_VERB_DELETE;
    if (!StrCmp(session->request->verb, "GET"))
        return SLON_HTTP_VERB_GET;
    if (!StrCmp(session->request->verb, "OPTIONS"))
        return SLON_HTTP_VERB_OPTIONS;
    if (!StrCmp(session->request->verb, "PATCH"))
        return SLON_HTTP_VERB_PATCH;
    if (!StrCmp(session->request->verb, "POST"))
        return SLON_HTTP_VERB_POST;
    return 999;
}

U8* @slon_http_request_header(SlonHttpSession* session, U8* key)
{
    U64 value = Json.Get(session->request->headers, key);
    if (!value)
        return "";
    return value;
}

Bool @slon_http_request_has_query_string(SlonHttpSession* session)
{
    return StrFind("?", session->request->raw_path) > 0 && !String.EndsWith("?", session->request->raw_path);
}
