JsonObject* @slon_api_v2_search_remote_account_from_webfinger(SlonHttpSession* session, U8* user, U8* domain)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    SLON_AUTH_ACCOUNT_ID

    I64 i;
    Bool tld_is_valid = FALSE;
    for (i = 0; i < SLON_TLDS->length; i++) {
        if (String.EndsWith(tld_array[i], domain)) {
            tld_is_valid = TRUE;
            break;
        }
    }
    if (!tld_is_valid) {
        @slon_log(LOG_HTTPD, "Could not query webfinger, tld is not valid for %s", domain);
        return NULL;
    }

    // WebFinger
    StrPrint(scratch_buffer, "https://%s/.well-known/webfinger?resource=acct:%s@%s", domain, user, domain);

    HttpUrl* url = @http_parse_url(scratch_buffer);
    if (!url) {
        @slon_log(LOG_HTTPD, "Could not query webfinger, malformed url or unspecified error");
        return NULL;
    }

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    JsonObject* http_headers = Json.CreateObject(slon_mem_task);
    http_headers->set("accept", "application/json", JSON_STRING);
    @http_response* resp = Http.Get(url, fetch_buffer, NULL, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not query webfinger, invalid response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    if (!resp->body.length) {
        @slon_log(LOG_HTTPD, "Could not query webfinger, empty response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    Free(fetch_buffer);

    JsonObject* webfinger_object = Json.Parse(resp->body.data, slon_mem_task);
    if (!webfinger_object) {
        @slon_log(LOG_HTTPD, "Error querying webfinger, object not present in response from remote server");
        return NULL;
    }

    if (!webfinger_object->@("links")) {
        @slon_log(LOG_HTTPD, "Error querying webfinger, links not present in object in response from remote server");
        return NULL;
    }

    U8* remote_actor = NULL;
    JsonArray* links = webfinger_object->a("links");
    JsonObject* link_object = NULL;
    for (i = 0; i < links->length; i++) {
        link_object = links->@(i);
        if (link_object->@("rel") && !StrICmp("self", link_object->@("rel"))) {
            remote_actor = link_object->@("href");
            break;
        }
    }

    if (!remote_actor) {
        @slon_log(LOG_HTTPD, "Error querying webfinger, actor not present in links in object in response from remote server");
        return NULL;
    }

    // We have the remote actor uri, let's fetch and create a local account
    fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    U8* signatory = db->o("actors")->o(@slon_api_account_by_id(account_id)->@("username"))->@("id");
    resp = @slon_activitypub_signed_request(remote_actor, fetch_buffer, NULL, SLON_HTTP_VERB_GET, signatory);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, invalid response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    if (!resp->body.length) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, empty response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    JsonObject* actor_object = Json.Parse(resp->body.data, slon_mem_task);
    JsonObject* account = @slon_accounts_create_local_for_remote_actor(session, actor_object, remote_actor, url);
    Free(fetch_buffer);

    return account;
}

U0 @slon_api_v2_search_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        // SLON_AUTH_ACCOUNT_ID
        JsonObject* results = Json.CreateObject(slon_mem_task);
        results->set("accounts", Json.CreateArray(slon_mem_task), JSON_ARRAY);
        results->set("statuses", Json.CreateArray(slon_mem_task), JSON_ARRAY);
        results->set("hashtags", Json.CreateArray(slon_mem_task), JSON_ARRAY);

        U8* q = request_json->@("q");
        if (!q) {
            goto slon_api_v2_search_get_return;
        }

        // FIXME: if "type" is specified, value must be "accounts" for now
        if (request_json->@("type") && StrICmp("accounts", request_json->@("type"))) {
            goto slon_api_v2_search_get_return;
        }

        if (q[0] == '@' || StrFind("@", request_json->@("q")) > 0) {
            I64 at_fragment_count = 0;
            U8* q_copy = @slon_strnew(session, q);
            U8** at_fragments = String.Split(q_copy, '@', &at_fragment_count);

            switch (at_fragment_count) {
            case 2:
            case 3:
                // Remote user
                StrPrint(scratch_buffer, "%s@%s", at_fragments[0], at_fragments[1]);
                JsonObject* remote_account = @slon_api_account_by_acct(scratch_buffer);
                if (!remote_account && request_json->@("resolve") && !StrICmp("true", request_json->@("resolve"))) {
                    // if "resolve" is TRUE, do WebFinger lookup if the remote account doesn't exist on this server
                    remote_account = @slon_api_v2_search_remote_account_from_webfinger(session, at_fragments[0], at_fragments[1]);
                }
                if (remote_account) {
                    results->a("accounts")->append(remote_account);
                }
                break;
            default:
                // Unsupported
                break;
            }

            @slon_free(session, q_copy);
        }

    slon_api_v2_search_get_return:
        session->send(results);
    } else {
        session->status(401);
    }
}
