U0 @slon_api_v2_search_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        // SLON_AUTH_ACCOUNT_ID
        // FIXME: Implement this
        JsonObject* results = Json.CreateObject();
        results->set("accounts", Json.CreateArray(), JSON_ARRAY);
        results->set("statuses", Json.CreateArray(), JSON_ARRAY);
        results->set("hashtags", Json.CreateArray(), JSON_ARRAY);

        U8* q = request_json->@("q");
        if (!q) {
            goto slon_api_v2_search_get_return;
        }

        if (q[0] == '@' || StrFind("@", request_json->@("q")) > 0) {
            // if "type" is specified, value must be "accounts"
            // if "resolve" is TRUE, do WebFinger lookup if the remote account doesn't exist on this server
            I64 at_fragment_count = 0;
            U8* q_copy = @slon_strnew(session, q);
            U8** at_fragments = String.Split(q_copy, '@', &at_fragment_count);

            switch (at_fragment_count) {
            case 2:
                // Local user
                // break;
            case 3:
                // Remote user
                StrPrint(scratch_buffer, "%s@%s", at_fragments[0], at_fragments[1]);
                JsonObject* remote_account = @slon_api_account_by_acct(scratch_buffer);
                if (remote_account) {
                    results->a("accounts")->append(Json.CreateItem(remote_account, JSON_OBJECT));
                } else {
                }
                break;
            default:
                // Unsupported
                break;
            }

            @slon_free(session, q_copy);
        }

    slon_api_v2_search_get_return:
        @slon_http_send_json(session, results);
        Json.Delete(results);
    } else {
        @slon_http_set_status_code(session, 401);
    }
}
