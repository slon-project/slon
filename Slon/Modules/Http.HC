#define SLON_HTTP_BUFFER_SIZE 1048576
#define SLON_HTTP_VERB_DELETE 1
#define SLON_HTTP_VERB_GET 2
#define SLON_HTTP_VERB_OPTIONS 3
#define SLON_HTTP_VERB_PATCH 4
#define SLON_HTTP_VERB_POST 5
#define SLON_HTTP_VERB_PUT 6

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
JsonArray* SLON_TLDS = Json.ParseFile("M:/Slon/Settings/tlds.json");

I64 tld_cnt = 0;
U8** tld_array = CAlloc(sizeof(U8*) * SLON_TLDS->length);
for (tld_cnt = 0; tld_cnt < SLON_TLDS->length; tld_cnt++) {
    tld_array[tld_cnt] = SLON_TLDS->@(tld_cnt);
}

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
    I64 path_segments_count;
    U8* path_segments_src;
    U8** path_segments;
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
    U8* actor_for_key_id;

    U8* (*header)(U8* key, U8* value = NULL);
    U0 (*send)(U64 payload, I64 size = NULL);
    U8* (*path)(I64 segment = NULL);
    I64 (*path_count)();
    I64 (*status)(I64 code = NULL);
    I64 (*verb)(Bool return_str = FALSE);
    U0 (*content_type)(U8* value);
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
    if (!StrICmp(value, "")) {
        Json.Unset(session->response->headers, key);
    } else {
        Json.Set(session->response->headers, key, value, JSON_STRING);
    }
}

U0 @slon_http_set_content_type(SlonHttpSession* session, U8* value)
{
    session->header("content-type", value);
}

U0 @slon_http_send_ap_json(SlonHttpSession* session, U64 json)
{
    // a stringified copy of "json" is created, a strnew is sent, we clean up stringified copy, sender cleans up "json"
    session->status(200);
    session->content_type("application/activity+json; charset=utf-8");
    U8* json_string = Json.Stringify(json);
    session->response->data = @slon_strnew(session, json_string);
    session->response->size = StrLen(session->response->data);
    Free(json_string);
}

U0 @slon_http_send_json(SlonHttpSession* session, U64 json)
{
    // a stringified copy of "json" is created, a strnew is sent, we clean up stringified copy, sender cleans up "json"
    session->status(200);
    session->content_type("application/json; charset=utf-8");
    U8* json_string = Json.Stringify(json);
    session->response->data = @slon_strnew(session, json_string);
    session->response->size = StrLen(session->response->data);
    Free(json_string);
}

U0 @slon_http_send_string(SlonHttpSession* session, U8* str)
{
    // a strnew of "str" is sent, sender cleans up "str"
    session->status(200);
    session->response->data = @slon_strnew(session, str);
    session->response->size = StrLen(str);
}

U0 @slon_http_send(SlonHttpSession* session, U64 data, I64 size)
{
    // a malloc copy of "data" is sent, sender cleans up "data"
    session->status(200);
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
    session->send(data, size);
    Free(data);
}

U0 @slon_http_send_html_file(SlonHttpSession* session, U8* path)
{
    session->content_type("text/html");
    @slon_http_send_file(session, path);
}

U0 @slon_http_send_json_file(SlonHttpSession* session, U8* path, U8* content_type = "application/json; charset=utf-8")
{
    session->content_type(content_type);
    @slon_http_send_file(session, path);
}

U8* @slon_http_request_path(SlonHttpSession* session, I64 segment = NULL)
{
    if (segment) {
        if (!session->request->path_segments_count || segment >= session->request->path_segments_count) {
            return NULL;
        }
        return session->request->path_segments[segment];
    } else {
        return session->request->path;
    }
}

I64 @slon_http_request_verb(SlonHttpSession* session, Bool return_str = FALSE)
{
    if (return_str) {
        if (!StrCmp(session->request->verb, "DELETE"))
            return "DELETE";
        if (!StrCmp(session->request->verb, "GET"))
            return "GET";
        if (!StrCmp(session->request->verb, "OPTIONS"))
            return "OPTIONS";
        if (!StrCmp(session->request->verb, "PATCH"))
            return "PATCH";
        if (!StrCmp(session->request->verb, "POST"))
            return "POST";
        if (!StrCmp(session->request->verb, "PUT"))
            return "PUT";
    } else {
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
        if (!StrCmp(session->request->verb, "PUT"))
            return SLON_HTTP_VERB_PUT;
    }
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

#define SLON_WRAPPER_MAGIC_NUMBER 0xC0DECAFEC0DECAFE

I64 @slon_session_status_wrapper_function(I64 code)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    if (code) {
        session->response->status_code = code;
    }
    return session->response->status_code;
}

U8* @slon_session_header_wrapper_function(U8* key, U8* value = NULL)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    if (!value) {
        return @slon_http_request_header(session, key);
    }
    @slon_http_set_header(session, key, value);
    return value;
}

U0 @slon_session_send_wrapper_function(U64 payload, I64 size = NULL)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    if (!payload) {
        return;
    }
    if (*payload(U32*) == JSON_SIG) {
        @slon_http_send_json(session, payload);
        return;
    }
    if (!size) {
        @slon_http_send_string(session, payload);
    } else {
        @slon_http_send(session, payload, size);
    }
}

I64 @slon_session_verb_wrapper_function(Bool return_str = FALSE)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    return @slon_http_request_verb(session, return_str);
}

U8* @slon_session_path_wrapper_function(I64 segment = NULL)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    return @slon_http_request_path(session, segment);
}

I64 @slon_session_path_count_wrapper_function()
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    return session->request->path_segments_count;
}

U0 @slon_session_content_type_wrapper_function(U8* value)
{
    SlonHttpSession* session = SLON_WRAPPER_MAGIC_NUMBER;
    session->header("content-type", value);
}
