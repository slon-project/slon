U0 @slon_admin_html_form_from_json_object(SlonHttpSession* session, U8* buf, JsonObject* o)
{
    if (!session || !buf || !o)
        return;

    JsonKey* key = o->keys;
    String.Append(buf, "<table>");
    while (key) {
        switch (key->type) {
        case JSON_BOOLEAN:
        case JSON_STRING:
        case JSON_NUMBER:
            String.Append(buf, "<tr><td><label>%s</label></td><td>", key->name);
            break;
        default:
            break;
        }
        switch (key->type) {
        case JSON_BOOLEAN:
            String.Append(buf, "<input name=%s type=checkbox %s>", key->name, @t(key->value, "checked", ""));
            break;
        case JSON_STRING:
            String.Append(buf, "<input name=%s type=text value=\"%s\" required>", key->name, key->value);
            break;
        case JSON_NUMBER:
            String.Append(buf, "<input name=%s type=text value=\"%d\" required>", key->name, ToI64(key->value));
            break;
        default:
            break;
        }
        String.Append(buf, "</td></tr>");
        key = key->next;
    }
    String.Append(buf, "</table>");
}

U0 @slon_admin_create_ap_actor(SlonHttpSession* session, JsonObject* acct)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    JsonObject* actors = db->o("actors");
    U8* domain = db->o("instance")->@("uri");
    U8* username = acct->@("username");

    JsonObject* actor = Json.Clone(SLON_DEFAULT_ACTOR_OBJECT, slon_mem_task);

    StrPrint(scratch_buffer, "https://%s/users/%s", domain, username);
    actor->set("id", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/following", domain, username);
    actor->set("following", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/followers", domain, username);
    actor->set("followers", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/inbox", domain, username);
    actor->set("inbox", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/outbox", domain, username);
    actor->set("outbox", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/collections/featured", domain, username);
    actor->set("featured", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s/collections/tags", domain, username);
    actor->set("featuredTags", scratch_buffer, JSON_STRING);
    actor->set("preferredUsername", username, JSON_STRING);
    actor->set("name", acct->@("display_name"), JSON_STRING);
    actor->set("summary", acct->@("note"), JSON_STRING);

    JsonObject* icon = Json.Parse("{\"type\":\"Image\"}", slon_mem_task);
    icon->set("url", acct->@("avatar"), JSON_STRING);
    actor->set("icon", icon, JSON_OBJECT);

    StrPrint(scratch_buffer, "https://%s/@%s", domain, username);
    actor->set("url", scratch_buffer, JSON_STRING);
    actor->set("published", acct->@("created_at"), JSON_STRING);
    actor->set("attachment", acct->@("fields"), JSON_ARRAY);
    actor->set("accountId", acct->@("id"), JSON_STRING);

    db->o("private_keys")->set(username, request_json->@("privatekey"), JSON_STRING);

    JsonObject* publickey = Json.CreateObject(slon_mem_task);
    StrPrint(scratch_buffer, "https://%s/users/%s#main-key", domain, username);
    publickey->set("id", scratch_buffer, JSON_STRING);
    StrPrint(scratch_buffer, "https://%s/users/%s", domain, username);
    publickey->set("owner", scratch_buffer, JSON_STRING);
    I64 x;
    publickey->set("publicKeyPem", @base64_decode(request_json->@("publickey"), &x), JSON_STRING);
    actor->set("publicKey", publickey, JSON_OBJECT);

    actors->set(acct->@("username"), actor, JSON_OBJECT);
    @slon_db_save_to_disk;
}

U0 @slon_admin_create_account(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    U8* id = @slon_api_generate_unique_id(session);
    U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

    JsonObject* acct = Json.CreateObject(slon_mem_task);
    JsonObject* source = Json.CreateObject(slon_mem_task);

    acct->set("id", id, JSON_STRING);
    acct->set("created_at", created_at, JSON_STRING);
    acct->set("username", request_json->@("username"), JSON_STRING);
    acct->set("acct", request_json->@("username"), JSON_STRING);
    acct->set("display_name", request_json->@("display_name"), JSON_STRING);
    acct->set("email", request_json->@("email"), JSON_STRING);
    acct->set("note", request_json->@("bio"), JSON_STRING);
    acct->set("avatar", request_json->@("avatar"), JSON_STRING);
    acct->set("header", request_json->@("header"), JSON_STRING);
    acct->set("avatar_static", acct->@("avatar"), JSON_STRING);
    acct->set("header_static", acct->@("header"), JSON_STRING);
    acct->set("last_status_at", "0", JSON_STRING);

    acct->set("followers_count", 0, JSON_NUMBER);
    acct->set("following_count", 0, JSON_NUMBER);
    acct->set("statuses_count", 0, JSON_NUMBER);

    acct->set("locked", FALSE, JSON_BOOLEAN);
    acct->set("bot", FALSE, JSON_BOOLEAN);
    acct->set("discoverable", FALSE, JSON_BOOLEAN);
    acct->set("indexable", FALSE, JSON_BOOLEAN);
    acct->set("hide_collections", FALSE, JSON_BOOLEAN);

    acct->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    acct->set("fields", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);

    source->set("privacy", "public", JSON_STRING);
    source->set("sensitive", FALSE, JSON_BOOLEAN);
    source->set("language", "", JSON_STRING);
    source->set("note", acct->@("note"), JSON_STRING);
    source->set("fields", acct->@("fields"), JSON_ARRAY);
    source->set("follow_requests_count", 0, JSON_NUMBER);

    acct->set("source", source, JSON_OBJECT);

    StrPrint(scratch_buffer, "https://%s/@%s", db->o("instance")->@("uri"), acct->@("username"));
    acct->set("url", scratch_buffer, JSON_STRING);

    db->a("accounts")->append(acct);
    db->o("statuses")->set(acct->@("id"), Json.CreateArray(slon_mem_task), JSON_ARRAY);
    @slon_admin_create_ap_actor(session, acct);

    @slon_db_instance_update_user_count;
    @slon_db_save_to_disk;

    @slon_free(session, created_at);
    @slon_free(session, id);
}

U0 @slon_admin_settings_accounts_new_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;
    String.Append(buf, "settings/accounts/new");
    String.Append(buf, "<br><br><form action=/settings/accounts/new/save>");
    @slon_admin_html_form_from_json_object(session, buf, SLON_DEFAULT_ACCT_OBJECT);
    String.Append(buf, "<br><br><input id=save type=submit value=Save></form>");
}

U0 @slon_admin_settings_accounts_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;
    String.Append(buf, "settings/accounts");
    String.Append(buf, "<br><br><table><tr><th>id</th><th>username</th></tr>");
    JsonArray* arr = db->a("accounts");
    JsonObject* acct;
    I64 i;
    for (i = 0; i < arr->length; i++) {
        acct = arr->@(i);
        if (acct) {
            String.Append(buf, "<tr><td>%s</td><td>%s</td></tr>", acct->@("id"), acct->@("username"));
        }
    }
    String.Append(buf, "</table><br><br><button onclick=\"window.location='/settings/accounts/new'\">New</button>");
}

U0 @slon_admin_settings_apps_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;
    String.Append(buf, "settings/apps");
    String.Append(buf, "<br><br>");
    U8* tmp = Json.Stringify(db->o("apps"), slon_mem_task);
    String.Append(buf, tmp);
    Free(tmp);
}

U0 @slon_admin_settings_oauth_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;
    String.Append(buf, "settings/oauth");
    String.Append(buf, "<br><br>");
    U8* tmp = Json.Stringify(db->o("oauth"), slon_mem_task);
    String.Append(buf, tmp);
    Free(tmp);
}

U0 @slon_admin_settings_instance_save_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    JsonObject* instance = db->o("instance");
    instance->set("uri", request_json->@("uri"));
    instance->set("title", request_json->@("title"));
    instance->set("short_description", request_json->@("short_description"));
    instance->set("description", request_json->@("description"));
    instance->set("email", request_json->@("email"));
    instance->set("version", request_json->@("version"));
    if (!request_json->@("registrations")) {
        instance->set("registrations", FALSE);
    } else {
        instance->set("registrations", !StrICmp("on", request_json->@("registrations")));
    }
    String.Append(buf, "<script>window.location='/settings/instance';</script>");
}

U0 @slon_admin_settings_instance_get(SlonHttpSession* session, U8* buf)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;

    String.Append(buf, "settings/instance");
    String.Append(buf, "<br><br><form action=/settings/instance/save>");
    @slon_admin_html_form_from_json_object(session, buf, db->o("instance"));
    String.Append(buf, "<br><br><input type=submit value=Save></form>");
}

U0 @slon_admin_delete_account(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (!request_json->@("id"))
        return;
    I64 i;
    JsonArray* accounts = db->a("accounts");
    JsonObject* account = NULL;
    for (i = 0; i < accounts->length; i++) {
        account = accounts->o(i);
        if (account && !StrICmp(request_json->@("id"), account->@("id"))) {
            accounts->remove(i);
            break;
        }
    }
    @slon_db_save_to_disk;
    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_admin_delete_announcement(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (!request_json->@("id"))
        return;
    I64 i;
    JsonArray* announcements = db->a("announcements");
    JsonObject* announcement = NULL;
    for (i = 0; i < announcements->length; i++) {
        announcement = announcements->o(i);
        if (announcement && !StrICmp(request_json->@("id"), announcement->@("id"))) {
            AdamLog("deleting announcement %d\n", i);
            announcements->remove(i);
            break;
        }
    }
    @slon_db_save_announcements_to_disk;
    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_admin_new_account(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (db->o("actors")->@(request_json->@("username"))) {
        StrPrint(scratch_buffer, "{\"error\":\"account already exists\"}");
        session->content_type("application/json");
        session->send(scratch_buffer, StrLen(scratch_buffer));
    } else {
        @slon_admin_create_account(session);
        session->send(SLON_EMPTY_JSON_OBJECT);
    }
}

U0 @slon_admin_new_announcement(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (request_json->@("content")) {
        U8* id = @slon_api_generate_unique_id(session);
        U8* timestamp = @slon_api_timestamp_from_cdate(session, Now);
        JsonObject* announcement = Json.CreateObject(slon_db_mem_task);
        announcement->set("id", id, JSON_STRING);
        announcement->set("content", request_json->@("content"), JSON_STRING);
        announcement->set("starts_at", NULL, JSON_NULL);
        announcement->set("ends_at", NULL, JSON_NULL);
        announcement->set("all_day", FALSE, JSON_BOOLEAN);
        announcement->set("published_at", timestamp, JSON_STRING);
        announcement->set("updated_at", timestamp, JSON_STRING);
        announcement->set("read", FALSE, JSON_BOOLEAN);
        announcement->set("read_users", Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
        announcement->set("mentions", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        announcement->set("statuses", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        announcement->set("tags", Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
        announcement->set("emojis", Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
        // Internally, "reactions" is { "emoji": [ "account_id", "account_id", ... ]}
        // This is presented to the client as: "reactions": [ { "name": "emoji", "count": xxx, "me": true/false }, ... ]
        announcement->set("reactions", Json.CreateObject(slon_db_mem_task), JSON_OBJECT);
        db->a("announcements")->append(announcement);
        @slon_db_save_announcements_to_disk;
        @slon_free(session, id);
        @slon_free(session, timestamp);
    }
    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_admin_manage_accounts(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    JsonArray* results = Json.CreateArray(slon_mem_task);
    I64 skip = Str2I64(request_json->@("skip"));
    I64 limit = 10;
    I64 i;
    I64 count = 0;
    JsonArray* accounts = db->a("accounts");
    for (i = skip; i < accounts->length && i < skip + limit; i++) {
        results->append(accounts->@(i));
        ++count;
    }
    JsonObject* o = Json.CreateObject(slon_mem_task);
    o->set("total", accounts->length, JSON_NUMBER);
    o->set("skip", skip, JSON_NUMBER);
    o->set("count", count, JSON_NUMBER);
    o->set("accounts", results, JSON_ARRAY);
    session->send(o);
}

U0 @slon_admin_info_stats(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    I64 free_memory = sys_code_bp->alloced_u8s - sys_code_bp->used_u8s;
    if (sys_data_bp) {
        free_memory += sys_data_bp->alloced_u8s - sys_data_bp->used_u8s;
    }
    StrPrint(scratch_buffer, "{");
    String.Append(scratch_buffer, "\"uptime\":%d,\"free_memory\":%d", cnts.jiffies, free_memory);
    String.Append(scratch_buffer, "}");

    session->content_type("application/json");
    session->send(scratch_buffer, StrLen(scratch_buffer));
}

U0 @slon_admin_server_get(SlonHttpSession* session)
{
    if (!db->@("setup")) {
        if (StrICmp("/", session->path())) {
            session->status(302);
            session->header("Location", "/");
        } else {
            @slon_http_send_html_file(session, "M:/Slon/Static/html/admin/setup_instance.html");
        }
        return;
    }

    if (!StrICmp("/info/stats", session->path())) {
        @slon_admin_info_stats(session);
        return;
    }

    if (!StrICmp("/delete/account", session->path())) {
        @slon_admin_delete_account(session);
        return;
    }

    if (!StrICmp("/delete/announcement", session->path())) {
        @slon_admin_delete_announcement(session);
        return;
    }

    if (!StrICmp("/manage/accounts", session->path())) {
        @slon_admin_manage_accounts(session);
        return;
    }

    if (!StrICmp("/manage/announcements", session->path())) {
        session->send(db->a("announcements"));
        return;
    }

    if (!StrICmp("/manage/instance", session->path())) {
        session->send(db->o("instance"));
        return;
    }

    if (!StrICmp("/manage/settings", session->path())) {
        session->send(db->o("settings"));
        return;
    }

    if (!StrICmp("/", session->path())) {
        @slon_http_send_html_file(session, "M:/Slon/Static/html/admin/main.html");
        return;
    }

    session->status(404);
}

U0 @slon_admin_setup_instance(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    JsonObject* instance = db->o("instance");
    instance->set("uri", request_json->@("uri"));
    instance->set("title", request_json->@("title"));
    instance->set("short_description", request_json->@("description"));
    instance->set("description", request_json->@("description"));
    instance->set("email", request_json->@("email"));
    instance->set("registrations", request_json->@("registrations"));
    @slon_db_save_to_disk;
    db->set("setup", TRUE);

    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_admin_save_settings(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    db->set("settings", request_json, JSON_OBJECT);
    @slon_db_save_settings_to_disk;

    session->send(SLON_EMPTY_JSON_OBJECT);
}

U0 @slon_admin_server_post(SlonHttpSession* session)
{
    if (StrFind("json", session->header("content-type")) > 0) {
        @slon_http_parse_request_as_json(session);
    }

    if (!StrICmp("/setup/instance", session->path()) || !StrICmp("/save/instance", session->path())) {
        @slon_admin_setup_instance(session);
        return;
    }

    if (!StrICmp("/save/settings", session->path())) {
        @slon_admin_save_settings(session);
        return;
    }

    if (!StrICmp("/new/account", session->path())) {
        @slon_admin_new_account(session);
        return;
    }

    if (!StrICmp("/new/announcement", session->path())) {
        @slon_admin_new_announcement(session);
        return;
    }

    session->status(404);
}

U0 @slon_admin_http_handle_get_request(SlonHttpSession* session)
{
    if (@slon_http_request_has_query_string(session)) {
        @slon_http_parse_query_string(session);
    }
    @slon_admin_server_get(session);
}

U0 @slon_admin_http_handle_post_request(SlonHttpSession* session)
{
    @slon_admin_server_post(session);
}

U0 @slon_admin_http_handle_request(SlonHttpSession* session)
{
    switch (session->verb()) {
    case SLON_HTTP_VERB_GET:
        @slon_admin_http_handle_get_request(session);
        break;
    case SLON_HTTP_VERB_POST:
        @slon_admin_http_handle_post_request(session);
        break;
    default:
        session->status(405);
    }
}

U0 @slon_admin_http_task(TcpSocket* s)
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
            goto slon_admin_http_task_send_response;
        }

        @slon_http_try_parse_request_headers(session);
    }

    // If we have a content-length header, consume until we receive all the data, then set request->data pointer and size
    if (StrLen(session->header("content-length"))) {
        I64 content_length = Str2I64(session->header("content-length"));
        while (session->request->buffer->data + session->request->buffer->size - session->request->data < content_length)
            @slon_http_receive(session);
    }

    @slon_admin_http_handle_request(session);

slon_admin_http_task_send_response:
    @slon_http_send_response(session);
    @slon_http_free_session(session);
    s->close();
}

Adam("U0 @spawn_slon_admin_http_task(TcpSocket *s){Spawn(%d, s, \"SlonAdminHttpTask\");};\n", &@slon_admin_http_task);
@tcp_socket_bind(9000, "@spawn_slon_admin_http_task");
