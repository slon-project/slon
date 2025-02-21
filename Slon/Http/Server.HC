SlonHttpBuffer* @slon_http_init_buffer(SlonHttpSession* session)
{
    SlonHttpBuffer* buffer = @slon_calloc(session, sizeof(SlonHttpBuffer));
    buffer->data = @slon_calloc(session, SLON_HTTP_BUFFER_SIZE);
    buffer->capacity = SLON_HTTP_BUFFER_SIZE;
    return buffer;
}

U0 @slon_http_free_response(SlonHttpSession* session, SlonHttpResponse* response)
{
    // FIXME: Free headers JsonObject
    if (response) {
        if (response->buffer && response->buffer->data) {
            @slon_free(session, response->buffer->data);
            @slon_free(session, response->buffer);
        }
        @slon_free(session, response);
    }
}

U0 @slon_http_free_request(SlonHttpSession* session, SlonHttpRequest* request)
{
    // FIXME: Free headers JsonObject
    if (request) {
        if (request->buffer && request->buffer->data) {
            @slon_free(session, request->buffer->data);
            @slon_free(session, request->buffer);
        }
        if (request->verb)
            @slon_free(session, session->request->verb);
        if (request->raw_path)
            @slon_free(session, session->request->raw_path);
        if (request->path)
            @slon_free(session, session->request->path);
        if (request->path_segments_src) {
            @slon_free(session, session->request->path_segments_src);
            Free(session->request->path_segments);
        }
        @slon_free(session, request);
    }
}

U0 @slon_http_free_session(SlonHttpSession* session)
{
    if (!session)
        return;
    @slon_http_free_response(session, session->response);
    @slon_http_free_request(session, session->request);
    I64 bytes_used = session->bytes_used - MSize2(session);
    Free(session->verb);
    Free(session->header);
    Free(session->status);
    Free(session->send);
    Free(session->path_count);
    Free(session->path);
    Free(session);
    if (bytes_used) {
        AdamLog("*** Session leaked %d bytes of memory ***\n", bytes_used);
    }
}

SlonHttpRequest* @slon_http_init_request(SlonHttpSession* session)
{
    SlonHttpRequest* request = @slon_calloc(session, sizeof(SlonHttpRequest));
    request->buffer = @slon_http_init_buffer(session);
    request->headers = Json.CreateObject();
    return request;
}

SlonHttpResponse* @slon_http_init_response(SlonHttpSession* session)
{
    SlonHttpResponse* response = @slon_calloc(session, sizeof(SlonHttpResponse));
    response->buffer = @slon_http_init_buffer(session);
    response->headers = Json.CreateObject();
    return response;
}

SlonHttpSession* @slon_http_init_session(TcpSocket* s)
{
    SlonHttpSession* session = CAlloc(sizeof(SlonHttpSession), adam_task);
    session->bytes_used = MSize2(session);
    session->s = s;
    session->request = @slon_http_init_request(session);
    session->response = @slon_http_init_response(session);

    // Create a copy of function and patch status
    U64 a;
    I64 code_size = MSize(&@slon_session_status_wrapper_function);
    session->status = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->status, &@slon_session_status_wrapper_function, code_size);

    a = session->status;
    a += 0x10;
    MemSetI64(a, session, 1);

    // Create a copy of function and patch header
    code_size = MSize(&@slon_session_header_wrapper_function);
    session->header = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->header, &@slon_session_header_wrapper_function, code_size);

    a = session->header;
    a += 0x16;
    MemSetI64(a, session, 1);

    a = session->header;
    a += 0x26;
    @patch_call_rel32(a, &@slon_http_request_header);

    a = session->header;
    a += 0x31;
    @patch_call_rel32(a, &@slon_http_set_header);

    // Create a copy of function and patch send
    code_size = MSize(&@slon_session_send_wrapper_function);
    session->send = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->send, &@slon_session_send_wrapper_function, code_size);

    a = session->send;
    a += 0x16;
    MemSetI64(a, session, 1);

    a = session->send;
    a += 0x33;
    @patch_call_rel32(a, &@slon_http_send_json);

    a = session->send;
    a += 0x41;
    @patch_call_rel32(a, &@slon_http_send_string);

    a = session->send;
    a += 0x4c;
    @patch_call_rel32(a, &@slon_http_send);

    // Create a copy of function and patch verb
    code_size = MSize(&@slon_session_verb_wrapper_function);
    session->verb = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->verb, &@slon_session_verb_wrapper_function, code_size);

    a = session->verb;
    a += 0x11;
    MemSetI64(a, session, 1);

    a = session->verb;
    a += 0x1b;
    @patch_call_rel32(a, &@slon_http_request_verb);

    // Create a copy of function and patch path
    code_size = MSize(&@slon_session_path_wrapper_function);
    session->path = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->path, &@slon_session_path_wrapper_function, code_size);

    a = session->path;
    a += 0x10;
    MemSetI64(a, session, 1);

    a = session->path;
    a += 0x1a;
    @patch_call_rel32(a, &@slon_http_request_path);

    // Create a copy of function and patch path_count
    code_size = MSize(&@slon_session_path_count_wrapper_function);
    session->path_count = CAlloc(code_size, adam_task->code_heap);
    MemCpy(session->path_count, &@slon_session_path_count_wrapper_function, code_size);

    a = session->path_count;
    a += 0x0b;
    MemSetI64(a, session, 1);

    return session;
}

U0 @slon_http_receive(SlonHttpSession* session)
{
    // FIXME: grow the buffer
    SlonHttpBuffer* buffer = session->request->buffer;
    I64 chunk_size = @tcp_socket_receive(session->s, buffer->data + buffer->size, 65536);
    buffer->size += chunk_size;
}

Bool @slon_http_request_headers_have_been_parsed(SlonHttpSession* session)
{
    return session->request->headers_have_been_parsed;
}

U0 @slon_http_buffer_append(SlonHttpBuffer* buffer, U8* src, I64 size)
{
    if (!buffer || !src || !size)
        return;
    MemCpy(buffer->data + buffer->size, src, size);
    buffer->size += size;
}

U0 @slon_http_buffer_append_string(SlonHttpBuffer* buffer, U8* str)
{
    @slon_http_buffer_append(buffer, str, StrLen(str));
}

U0 @slon_http_send_response(SlonHttpSession* session)
{
    SlonHttpBuffer* buffer = session->response->buffer;
    U8 scratch_buffer[256][4];

    StrPrint(scratch_buffer[0], "%d", session->response->status_code);
    StrPrint(scratch_buffer[1], "HTTP/1.0 %d %s\r\n", session->response->status_code, Json.Get(SLON_HTTP_STATUS_CODES, scratch_buffer[0]));
    @slon_http_buffer_append_string(buffer, scratch_buffer[1]);

    JsonKey* key = session->response->headers->keys;
    while (key) {
        StrPrint(scratch_buffer[0], "%s: %s\r\n", key->name, key->value);
        @slon_http_buffer_append_string(buffer, scratch_buffer[0]);
        key = key->next;
    }

    StrPrint(scratch_buffer[0], "content-length: %d\r\n", session->response->size);
    @slon_http_buffer_append_string(buffer, scratch_buffer[0]);

    StrCpy(scratch_buffer[0], "pragma: no-cache\r\n\r\n");
    @slon_http_buffer_append_string(buffer, scratch_buffer[0]);

    if (session->response->data && session->response->size) {
        @slon_http_buffer_append(buffer, session->response->data, session->response->size);
        @slon_free(session, session->response->data);
    }

    @tcp_socket_send(session->s, buffer->data, buffer->size);
}

U0 @slon_http_rstrip_char_from_string(U8* str, I64 ch)
{
    while (str[StrLen(str) - 1] == ch)
        str[StrLen(str) - 1] = NULL;
}

U0 @slon_http_try_parse_request_headers(SlonHttpSession* session)
{
    SlonHttpBuffer* buffer = session->request->buffer;
    I64 i = 0;
    // Do we have headers yet? let's find out
    while (i < buffer->size) {
        if (!MemCmp(buffer->data + i, "\r\n\r\n", 4)) {
            i += 4;
            goto slon_http_parse_request_headers;
        }
        ++i;
    }
    return;

slon_http_parse_request_headers:
    // Set pointer for request content
    session->request->data = buffer->data + i;

    // We have headers, let's parse them
    U8* raw_headers = @slon_calloc(session, i);
    MemCpy(raw_headers, buffer->data, i - 4);

    I64 raw_header_lines_count = 0;
    U8** raw_header_lines = String.Split(raw_headers, '\n', &raw_header_lines_count);

    if (!raw_header_lines_count) {
        // FIXME: Handle this
    }

    I64 request_first_line_segments_count = 0;
    U8** request_first_line_segments = String.Split(raw_header_lines[0], ' ', &request_first_line_segments_count);

    if (request_first_line_segments_count < 2) {
        // FIXME: Handle this
    }

    session->request->verb = @slon_strnew(session, request_first_line_segments[0]);
    session->request->raw_path = @slon_strnew(session, request_first_line_segments[1]);
    session->request->path = @slon_strnew(session, session->request->raw_path);
    if (StrFind("?", session->request->raw_path)) {
        *(StrFind("?", session->request->path)) = NULL;
    }
    if (StrFind("/", session->request->path)) {
        session->request->path_segments_src = @slon_strnew(session, session->request->path);
        session->request->path_segments = String.Split(session->request->path_segments_src, '/', &session->request->path_segments_count);
    }

    U8* key;
    U8* value;

    for (i = 1; i < raw_header_lines_count; i++) {
        key = NULL;
        value = NULL;
        if (StrFind(": ", raw_header_lines[i])) {
            value = StrFind(": ", raw_header_lines[i]) + 2;
            @slon_http_rstrip_char_from_string(value, '\r');
            *(StrFind(": ", raw_header_lines[i])) = NULL;
            key = raw_header_lines[i];
            Json.Set(session->request->headers, key, value, JSON_STRING);
        }
    }

    @slon_free(session, raw_headers);
    session->request->headers_have_been_parsed = TRUE;
}

U0 @slon_http_authorize(SlonHttpSession* session)
{
    if (StrLen(session->header("authorization"))) {
        U8* access_token = StrFind(" ", session->header("authorization")) + 1;
        session->auth = db->o("oauth")->o("tokens")->@(access_token);
    }
}

U0 @slon_http_debug_print_request(SlonHttpSession* session, Bool show_headers = FALSE)
{
    AdamLog("[httpd] %d => request: %s %s\n", session->s, session->request->verb, session->request->raw_path);
    if (show_headers) {
        U8* headers_stringified = Json.Stringify(session->request->headers);
        AdamLog("[httpd] %d => headers: %s\n", session->s, headers_stringified);
        Free(headers_stringified);
        //@slon_free(session, headers_stringified);
    }
}

U0 @slon_http_debug_print_response(SlonHttpSession* session, Bool show_headers = FALSE)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "%d", session->response->status_code);
    AdamLog("[httpd] %d <= response: %d %s\n", session->s, session->response->status_code, Json.Get(SLON_HTTP_STATUS_CODES, scratch_buffer));
    if (show_headers) {
        U8* headers_stringified = Json.Stringify(session->response->headers);
        AdamLog("[httpd] %d <= headers: %s\n", session->s, headers_stringified);
        Free(headers_stringified);
        //@slon_free(session, headers_stringified);
    }
    if (session->response->data) {
        AdamLog("data: %s\n", session->response->data);
    }
}

U8* @slon_http_json_string_from_form_urlencoded_string(SlonHttpSession* session, U8* form_urlencoded_string)
{
    // FIXME: Implement arrays, objects per https://jsonapi.org/format/#fetching
    U8* json_string = @slon_calloc(session, StrLen(form_urlencoded_string) * 2);
    String.Append(json_string, "{");
    U8* form_urlencoded_string_copy = @slon_strnew(session, form_urlencoded_string);
    I64 raw_values_count = 0;
    U8** raw_values = String.Split(form_urlencoded_string_copy, '&', &raw_values_count);
    I64 i = 0;
    U8* key;
    U8* value;
    for (i = 0; i < raw_values_count; i++) {
        value = StrFind("=", raw_values[i]) + 1;
        *(StrFind("=", raw_values[i])) = NULL;
        key = raw_values[i];
        U8* decoded_value = @slon_http_decode_urlencoded_string(session, value);
        String.Append(json_string, "\"%s\":\"%s\"", key, decoded_value);
        @slon_free(session, decoded_value);
        if (i < raw_values_count - 1) {
            String.Append(json_string, ",");
        }
    }
    String.Append(json_string, "}");
    @slon_free(session, form_urlencoded_string_copy);
    return json_string;
}

U8* @slon_http_json_string_from_multipart_form_data(SlonHttpSession* session, U8* multipart_form_data)
{
    U8* json_string = @slon_calloc(session, StrLen(multipart_form_data) * 2);
    String.Append(json_string, "{");
    U8* multipart_form_data_copy = @slon_strnew(session, multipart_form_data);

    U8* boundary = StrFind("boundary=", session->header("content-type")) + 9;
    // Strip begin double-quotes and ending CRLF, double-quotes
    while (boundary[0] == '"')
        boundary++;

    while (boundary[StrLen(boundary) - 1] == '\"' || boundary[StrLen(boundary) - 1] == ' ' || boundary[StrLen(boundary) - 1] == '\r' || boundary[StrLen(boundary) - 1] == '\n')
        boundary[StrLen(boundary) - 1] = NULL;

    I64 state = SLON_MULTIPART_PARSER_CONSUME_BOUNDARY;
    I64 lines_count = 0;
    U8** lines = String.Split(multipart_form_data_copy, '\n', &lines_count);

    U8* line;
    U8* name;
    U8* replace_line;

    I64 i = 0;
    while (i < lines_count) {
        line = lines[i];
        // Strip any ending CRLF
        while (line[StrLen(line) - 1] == '\r' || line[StrLen(line) - 1] == '\n') {
            line[StrLen(line) - 1] = NULL;
        }
        switch (state) {
        case SLON_MULTIPART_PARSER_CONSUME_BOUNDARY:
            if (StrFind(boundary, line)) {
                state = SLON_MULTIPART_PARSER_CONSUME_CONTENT_DISPOSITION;
            }
            break;
        case SLON_MULTIPART_PARSER_CONSUME_CONTENT_DISPOSITION:
            if (StrFind("ontent-", line) && StrFind("isposition:", line) && StrFind("name=", line)) {
                name = StrFind("name=", line) + 5;
                // Strip begin/end double-quotes
                while (name[0] == '"')
                    name++;
                while (name[StrLen(name) - 1] == '\"')
                    name[StrLen(name) - 1] = NULL;
                String.Append(json_string, "\"%s\":\"", name);
                state = SLON_MULTIPART_PARSER_CONSUME_CONTENT;
            }
            break;
        case SLON_MULTIPART_PARSER_CONSUME_CONTENT:
            if (StrFind(boundary, line)) {
                String.Append(json_string, "\"");
                if (!String.EndsWith("--", line)) {
                    String.Append(json_string, ",");
                    state = SLON_MULTIPART_PARSER_CONSUME_CONTENT_DISPOSITION;
                } else {
                    state = SLON_MULTIPART_PARSER_DONE;
                }
            } else {
                replace_line = String.Replace(line, "\"", "\\\"");
                String.Append(json_string, replace_line);
                Free(replace_line);
            }
            break;
        default:
            break;
        }
        ++i;
    }
    String.Append(json_string, "}");
    @slon_free(session, multipart_form_data_copy);
    return json_string;
}

U0 @slon_http_parse_query_string(SlonHttpSession* session)
{
    U8* raw_path_copy = @slon_strnew(session, session->request->raw_path);
    I64 raw_path_split_count = 0;
    U8** raw_path_split = String.Split(raw_path_copy, '?', &raw_path_split_count);
    if (raw_path_split_count > 1) {
        U8* json_string = @slon_http_json_string_from_form_urlencoded_string(session, raw_path_split[1]);
        session->request->json = Json.Parse(json_string);
        @slon_free(session, json_string);
    }
    @slon_free(session, raw_path_copy);
}

U0 @slon_http_parse_request_as_form_urlencoded(SlonHttpSession* session)
{
    U8* json_string = @slon_http_json_string_from_form_urlencoded_string(session, session->request->data);
    session->request->json = Json.Parse(json_string);
    @slon_free(session, json_string);
}

U0 @slon_http_parse_request_as_multipart_form_data(SlonHttpSession* session)
{
    U8* json_string = @slon_http_json_string_from_multipart_form_data(session, session->request->data);
    session->request->json = Json.Parse(json_string);
    @slon_free(session, json_string);
}

U0 @slon_http_parse_request_as_json(SlonHttpSession* session)
{
    session->request->json = Json.Parse(session->request->data);
}

U0 @slon_http_handle_delete_request(SlonHttpSession* session)
{

    /* clang-format off */

    #include "Endpoints/Delete/Statuses";

    /* clang-format on */

    // FIXME: Implement this
    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_http_handle_get_request(SlonHttpSession* session)
{
    if (@slon_http_request_has_query_string(session)) {
        @slon_http_parse_query_string(session);
    }

    SLON_DEBUG_PRINT_REQUEST_JSON

    /* clang-format off */

    #include "Endpoints/Get/Accounts";
    #include "Endpoints/Get/ActivityPub";
    #include "Endpoints/Get/Blocks";
    #include "Endpoints/Get/Bookmarks";
    #include "Endpoints/Get/Conversations";
    #include "Endpoints/Get/CustomEmojis";
    #include "Endpoints/Get/Favourites";
    #include "Endpoints/Get/Filters";
    #include "Endpoints/Get/FollowRequests";
    #include "Endpoints/Get/FollowedTags";
    #include "Endpoints/Get/Instance";
    #include "Endpoints/Get/Notifications";
    #include "Endpoints/Get/OAuth";
    #include "Endpoints/Get/Search";
    #include "Endpoints/Get/Suggestions";
    #include "Endpoints/Get/Timelines";
    #include "Endpoints/Get/Web";
    #include "Endpoints/Get/WellKnown";

    /* clang-format on */

    session->status(404);
}

U0 @slon_http_handle_patch_request(SlonHttpSession* session)
{
    if (StrFind("json", session->header("content-type")) > 0) {
        @slon_http_parse_request_as_json(session);
    }
    if (String.BeginsWith("application/x-www-form-urlencoded", session->header("content-type"))) {
        @slon_http_parse_request_as_form_urlencoded(session);
    }
    if (String.BeginsWith("multipart/form-data", session->header("content-type"))) {
        @slon_http_parse_request_as_multipart_form_data(session);
    }

    SLON_DEBUG_PRINT_REQUEST_JSON

    /* clang-format off */

    #include "Endpoints/Patch/Accounts";

    /* clang-format on */

    session->status(404);
}

U0 @slon_http_handle_post_request(SlonHttpSession* session)
{
    if (StrFind("json", session->header("content-type")) > 0) {
        @slon_http_parse_request_as_json(session);
    }
    if (String.BeginsWith("application/x-www-form-urlencoded", session->header("content-type"))) {
        @slon_http_parse_request_as_form_urlencoded(session);
    }
    if (String.BeginsWith("multipart/form-data", session->header("content-type"))) {
        @slon_http_parse_request_as_multipart_form_data(session);
    }
    // Workaround for IceCubesApp: https://github.com/Dimillian/IceCubesApp/issues/2235
    if (!StrLen(session->header("content-type")) && @slon_http_request_has_query_string(session)) {
        @slon_http_parse_query_string(session);
    }

    SLON_DEBUG_PRINT_REQUEST_JSON

    /* clang-format off */

    #include "Endpoints/Post/Accounts";
    #include "Endpoints/Post/ActivityPub";
    #include "Endpoints/Post/Apps";
    #include "Endpoints/Post/OAuth";
    #include "Endpoints/Post/Statuses";

    /* clang-format on */

    session->status(404);
}

U0 @slon_http_handle_request(SlonHttpSession* session)
{

    //        .purge_expired_idempotency_keys()
    @slon_http_authorize(session);
    switch (session->verb()) {
    case SLON_HTTP_VERB_DELETE:
        @slon_http_handle_delete_request(session);
        break;
    case SLON_HTTP_VERB_GET:
        @slon_http_handle_get_request(session);
        break;
    case SLON_HTTP_VERB_OPTIONS:
        session->status(200);
        break;
    case SLON_HTTP_VERB_PATCH:
        @slon_http_handle_patch_request(session);
        break;
    case SLON_HTTP_VERB_POST:
        @slon_http_handle_post_request(session);
        break;
    default:
        session->status(405);
    }
}

U0 @slon_http_task(TcpSocket* s)
{
    // Bail if we can't acquire socket for some reason
    if (!@tcp_socket_accept(s))
        return;

    // Init session
    SlonHttpSession* session = @slon_http_init_session(s);

    // Parse headers if they are available
    while (!@slon_http_request_headers_have_been_parsed(session)) {
        @slon_http_receive(session);

        // Handle malformed requests (anything less than "GET / HTTP/1.0\r\n\r\n" is probably a bad request)
        if (session->request->buffer->size < 18) {
            session->status(400);
            goto slon_http_task_send_response;
        }

        @slon_http_try_parse_request_headers(session);
    }

    //@slon_http_debug_print_request(session, FALSE);

    // If we have a content-length header, consume until we receive all the data, then set request->data pointer and size
    if (StrLen(session->header("content-length"))) {
        I64 content_length = Str2I64(session->header("content-length"));
        while (session->request->buffer->data + session->request->buffer->size - session->request->data < content_length)
            @slon_http_receive(session);
    }

    @slon_http_handle_request(session);

slon_http_task_send_response:
    //@slon_http_debug_print_response(session, FALSE);

    @slon_http_send_response(session);

    @slon_http_free_session(session);

    AdamLog("\n");
    s->close();
}

Adam("U0 @spawn_slon_http_task(TcpSocket *s){Spawn(%d, s, \"SlonHttpTask\");};\n", &@slon_http_task);
@tcp_socket_bind(80, "@spawn_slon_http_task");
