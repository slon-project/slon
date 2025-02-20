JsonObject* @slon_api_v2_search_remote_account_from_webfinger(SlonHttpSession* session, U8* user, U8* domain)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

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

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    JsonObject* http_headers = Json.CreateObject();
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

    JsonObject* webfinger_object = Json.Parse(resp->body.data);
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
    url = @http_parse_url(remote_actor);
    if (!url) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, malformed url or unspecified error");
        return NULL;
    }

    fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    resp = Http.Get(url, fetch_buffer, NULL, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, invalid response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    if (!resp->body.length) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, empty response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    Free(fetch_buffer);

    JsonObject* actor_object = Json.Parse(resp->body.data);

    U8* id = @slon_api_generate_unique_id(session);
    U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

    JsonObject* account = Json.CreateObject();

    account->set("id", id, JSON_STRING);
    account->set("created_at", created_at, JSON_STRING);
    account->set("username", actor_object->@("preferredUsername"), JSON_STRING);
    StrPrint(scratch_buffer, "%s@%s", actor_object->@("preferredUsername"), url->host);
    account->set("acct", scratch_buffer, JSON_STRING);
    account->set("display_name", actor_object->@("name"), JSON_STRING);
    account->set("email", "", JSON_STRING);
    account->set("note", actor_object->@("summary"), JSON_STRING);
    if (actor_object->@("icon")) {
        account->set("avatar", actor_object->o("icon")->@("url"), JSON_STRING);
        account->set("avatar_static", actor_object->o("icon")->@("url"), JSON_STRING);
    } else {
        account->set("avatar", SLON_MISSING_ACCOUNT_AVATAR, JSON_STRING);
        account->set("avatar_static", SLON_MISSING_ACCOUNT_AVATAR, JSON_STRING);
    }
    account->set("header", "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==", JSON_STRING);
    account->set("header_static", "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==", JSON_STRING);
    account->set("last_status_at", "0", JSON_STRING);
    account->set("followers_count", 0, JSON_NUMBER);
    account->set("following_count", 0, JSON_NUMBER);
    account->set("statuses_count", 0, JSON_NUMBER);
    account->set("locked", FALSE, JSON_BOOLEAN);
    account->set("bot", FALSE, JSON_BOOLEAN);
    account->set("discoverable", FALSE, JSON_BOOLEAN);
    account->set("indexable", FALSE, JSON_BOOLEAN);
    account->set("hide_collections", FALSE, JSON_BOOLEAN);
    account->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    account->set("fields", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    account->set("url", remote_actor, JSON_STRING);
    account->set("remote_actor", remote_actor, JSON_STRING);

    db->a("accounts")->append(Json.CreateItem(account, JSON_OBJECT));
    // db->o("statuses")->set(acct->@("id"), Json.CreateArray(), JSON_ARRAY);
    @slon_db_save_to_disk;

    @slon_free(session, created_at);
    @slon_free(session, id);

    return account;
}

U0 @slon_api_v2_search_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        // SLON_AUTH_ACCOUNT_ID
        JsonObject* results = Json.CreateObject();
        results->set("accounts", Json.CreateArray(), JSON_ARRAY);
        results->set("statuses", Json.CreateArray(), JSON_ARRAY);
        results->set("hashtags", Json.CreateArray(), JSON_ARRAY);

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
                    results->a("accounts")->append(Json.CreateItem(remote_account, JSON_OBJECT));
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
        Json.Delete(results);
    } else {
        session->status(401);
    }
}
