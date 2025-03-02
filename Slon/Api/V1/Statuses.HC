U0 (*@slon_api_status_create_fedi)(JsonObject* status) = NULL;
U0 (*@slon_api_status_delete_fedi)(JsonObject* status) = NULL;

U0 @slon_api_v1_statuses_delete_file_from_catbox(SlonHttpSession* session, U8* filename)
{
    if (!session || !filename) {
        return;
    }

    // build the multipart/form-data payload

    U8* payload = @slon_calloc(session, 4096);
    I64 payload_size = 0;

    U8* boundary = "----------SlonFormBoundary00";
    StrPrint(payload, "--%s\r\n", boundary);

    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "reqtype", "deletefiles", boundary);
    if (db->o("settings")->@("catbox_userhash")) {
        String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "userhash", db->o("settings")->@("catbox_userhash"), boundary);
    }
    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "files", filename, boundary);
    payload_size = StrLen(payload);

    // build the http headers
    U8* headers = @slon_calloc(session, 4096);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = @slon_calloc(session, send_buffer_size);

    MemCpy(send_buffer, headers, StrLen(headers));
    MemCpy(send_buffer + StrLen(headers), payload, payload_size);

    TlsSocket* s = @tls_socket_create("catbox.moe", 443);
    while (!@tls_established(s->ctx))
        Sleep(1);

    s->send(send_buffer, send_buffer_size);

    I64 bytes_received = 0;
    I64 response_buffer_size = 0;
    U8* response_buffer = @slon_calloc(session, 4096);

    while (!bytes_received) {
        bytes_received = s->receive(response_buffer + response_buffer_size, 4096);
        response_buffer_size += bytes_received;
    }

    s->close();

    @slon_free(session, response_buffer);
    @slon_free(session, send_buffer);
    @slon_free(session, payload);
    @slon_free(session, headers);
}

JsonObject* @slon_api_v1_statuses_lookup_by_id(U8* id, JsonArray* statuses)
{
    if (!id || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (status->@("id") && !StrICmp(status->@("id"), id)) {
            return status;
        }
    }
    return NULL;
}

JsonArray* @slon_api_v1_statuses_lookup_descendants_by_id(U8* id, JsonArray* statuses)
{
    if (!id || !statuses) {
        return NULL;
    }
    I64 i;
    JsonArray* arr = Json.CreateArray();
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (status->@("in_reply_to_id") && !StrICmp(status->@("in_reply_to_id"), id)) {
            arr->append(Json.CreateItem(status, JSON_OBJECT));
        }
    }
    return arr;
}

JsonObject* @slon_api_v1_statuses_find_by_id(U8* id, U8* account_id)
{
    if (!id) {
        return NULL;
    }
    JsonObject* status = NULL;
    // Lookup in public timeline
    status = @slon_api_v1_statuses_lookup_by_id(id, db->o("timelines")->a("public"));
    if (status) {
        return status;
    }
    if (!account_id) {
        return NULL;
    }
    // Then, lookup in home timeline
    status = @slon_api_v1_statuses_lookup_by_id(id, db->o("timelines")->o("home")->a(account_id));
    if (status) {
        return status;
    }
    // Finally, lookup in account's statuses
    status = @slon_api_v1_statuses_lookup_by_id(id, db->o("statuses")->a(account_id));
    if (status) {
        return status;
    }
    return NULL;
}

JsonArray* @slon_api_v1_statuses_find_descendants_by_id(U8* id, U8* account_id)
{
    if (!id || !account_id) {
        return NULL;
    }
    JsonArray* arr = NULL;
    // Lookup in public timeline
    arr = @slon_api_v1_statuses_lookup_descendants_by_id(id, db->o("timelines")->a("public"));
    if (arr && arr->length) {
        return arr;
    }
    // Then, lookup in home timeline
    arr = @slon_api_v1_statuses_lookup_descendants_by_id(id, db->o("timelines")->o("home")->a(account_id));
    if (arr && arr->length) {
        return arr;
    }
    // Finally, lookup in account's statuses
    arr = @slon_api_v1_statuses_lookup_descendants_by_id(id, db->o("statuses")->a(account_id));
    if (arr && arr->length) {
        return arr;
    }
    return SLON_EMPTY_JSON_ARRAY;
}

U0 @slon_api_v1_statuses_query(SlonHttpSession* session, JsonArray* status_array)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    SLON_AUTH_ACCOUNT_ID

    I64 i;
    I64 count = 0;
    // FILTERS
    I64 limit = 20; // default
    U64 max_id = 0;
    U64 min_id = 0;
    Bool only_media = request_json->@("only_media");
    Bool exclude_replies = request_json->@("exclude_replies");
    Bool exclude_reblogs = request_json->@("exclude_reblogs");
    no_warn exclude_reblogs;
    Bool pinned = request_json->@("pinned");
    // FIXME: Implement "only_media", "exclude_reblogs", "tagged"
    Bool exclude_status = FALSE;
    U64 status_id = 0;
    if (StrLen(request_json->@("limit")) > 0) {
        // 40 = maximum per https://docs.joinmastodon.org/methods/accounts/#statuses
        limit = MinI64(40, Str2I64(request_json->@("limit")));
    }
    if (StrLen(request_json->@("max_id")) > 0) {
        max_id = Str2I64(request_json->@("max_id"));
    }
    if (StrLen(request_json->@("min_id")) > 0) {
        min_id = Str2I64(request_json->@("min_id"));
    }
    if (request_json->@("since_id") && StrLen(request_json->@("since_id")) > 0 && !min_id) {
        min_id = Str2I64(request_json->@("since_id"));
    }
    JsonArray* statuses = Json.CreateArray();
    JsonObject* status = NULL;
    if (status_array && status_array->length) {
        for (i = status_array->length - 1; i > -1; i--) {
            status = status_array->o(i);
            status_id = Str2I64(status->@("id"));
            exclude_status = FALSE;
            if (status->@("deleted")) {
                exclude_status = TRUE;
            }
            if (max_id > 0 && status_id >= max_id) {
                exclude_status = TRUE;
            }
            if (min_id > 0 && status_id <= min_id) {
                exclude_status = TRUE;
            }
            if (only_media && !Json.Get(status, "media_attachments")(JsonArray*)->length) {
                exclude_status = TRUE;
            }
            if (exclude_replies && StrLen(status->@("in_reply_to_account_id")) > 0 && StrICmp(account_id, status->@("in_reply_to_account_id"))) {
                exclude_status = TRUE;
            }
            if (pinned && !status->@("pinned")) {
                exclude_status = TRUE;
            }
            if (!exclude_status) {
                statuses->append(Json.CreateItem(status, JSON_OBJECT));
                count++;
            }
            if (limit > 0 && count >= limit) {
                break;
            }
        }
    }
    session->send(statuses);
    Json.Delete(statuses);
}

U0 @slon_api_v1_statuses_delete(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        JsonArray* statuses = db->o("statuses")->a(account_id);
        if (!statuses || !statuses->length) {
            session->send(SLON_EMPTY_JSON_OBJECT);
            return;
        }

        if (session->path_count() < 4) {
            goto slon_api_v1_statuses_delete_return;
        }

        U8* id = session->path(3);
        JsonObject* status;
        JsonObject* fedi_status;
        JsonArray* media_attachments = NULL;
        JsonObject* attachment = NULL;
        U8* attachment_url_ptr = NULL;

        I64 i;
        I64 j;
        for (i = 0; i < statuses->length; i++) {
            status = statuses->@(i);
            if (!StrICmp(status->@("id"), id)) {
                fedi_status = Json.Clone(status);
                status->set("deleted", TRUE, JSON_BOOLEAN);
                media_attachments = status->a("media_attachments");
                if (db->o("settings")->@("catbox_userhash") && media_attachments && media_attachments->length) {
                    for (j = 0; j < media_attachments->length; j++) {
                        attachment = media_attachments->@(j);
                        attachment_url_ptr = attachment->@("url");
                        if (attachment_url_ptr) {
                            attachment_url_ptr += StrLen(attachment_url_ptr) - 1;
                            while (*(attachment_url_ptr - 1) != '/') {
                                --attachment_url_ptr;
                            }
                            @slon_api_v1_statuses_delete_file_from_catbox(session, attachment_url_ptr);
                        }
                    }
                }
                @slon_db_save_statuses_to_disk;
                @slon_db_instance_decrement_status_count;
                @slon_db_save_instance_to_disk;
                if (@slon_api_status_delete_fedi) {
                    @slon_api_status_delete_fedi(fedi_status);
                }
                goto slon_api_v1_statuses_delete_return;
            }
        }

    slon_api_v1_statuses_delete_return:
        session->send(SLON_EMPTY_JSON_OBJECT);
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_statuses_get(SlonHttpSession* session)
{

    if (session->path_count() < 4) {
        session->status(400);
        return;
    }

    if (session->path_count() > 4 && !StrICmp("history", session->path(4))) {
        // NOTE: We probably won't support this any time soon
        session->send(SLON_EMPTY_JSON_ARRAY);
        return;
    }

    U8* id = session->path(3);
    JsonObject* status = NULL;

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        if (session->path_count() > 4 && !StrICmp("context", session->path(4))) {
            JsonObject* context = Json.CreateObject();
            context->set("ancestors", Json.CreateArray(), JSON_ARRAY);

            // Get ancestors
            id = session->path(3);
            status = @slon_api_v1_statuses_find_by_id(id, account_id);
            while (status && status->@("in_reply_to_id")) {
                id = status->@("in_reply_to_id");
                status = @slon_api_v1_statuses_find_by_id(id, account_id);
                if (status) {
                    context->a("ancestors")->append(Json.CreateItem(status, JSON_OBJECT));
                }
            }

            // Get descendants
            id = session->path(3);
            context->set("descendants", @slon_api_v1_statuses_find_descendants_by_id(id, account_id), JSON_ARRAY);

            session->send(context);
            return;
        }

        status = @slon_api_v1_statuses_find_by_id(id, account_id);
        if (status) {
            session->send(status);
            return;
        }
        session->status(404);
    } else {
        status = @slon_api_v1_statuses_find_by_id(id, NULL);
        if (status) {
            session->send(status);
            return;
        }
        session->status(404);
    }
}

U0 @slon_api_v1_statuses_post(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        Bool idempotency_key_already_seen = FALSE;
        U8* idempotency_key = session->header("idempotency-key");
        if (StrLen(idempotency_key) > 0 && db->o("idempotency_keys")->@(idempotency_key)) {
            idempotency_key_already_seen = TRUE;
        }
        if (!idempotency_key_already_seen) {
            Json.Set(db->o("idempotency_keys"), idempotency_key, Now, JSON_NUMBER);
        }

        U8* id = @slon_api_generate_unique_id(session);
        U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

        JsonObject* app_object = db->o("apps")->@(Json.Get(session->auth, "client_id"));

        JsonObject* status_app = Json.CreateObject();
        status_app->set("name", app_object->@("name"), JSON_STRING);
        status_app->set("website", app_object->@("website"), JSON_STRING);

        JsonObject* account_object = Json.Clone(@slon_api_account_by_id(account_id));
        account_object->unset("source");

        // U8* language = request_json->@("language");
        U8* username = account_object->@("username");

        Bool sensitive = request_json->@("sensitive") > 0;
        if (request_json->@("sensitive", TRUE)(JsonKey*)->type == JSON_STRING) {
            sensitive = (!StrICmp("true", request_json->@("sensitive")));
        }
        U8* in_reply_to_id = request_json->@("in_reply_to_id");
        U8* visibility = request_json->@("visibility");

        if (!StrLen(visibility)) {
            visibility = "public";
        }

        StrPrint(scratch_buffer, "https://%s/users/%s/statuses/%s", db->o("instance")->@("uri"), username, id);
        U8* uri = @slon_strnew(session, scratch_buffer);
        StrPrint(scratch_buffer, "https://%s/@%s/%s", db->o("instance")->@("uri"), username, id);
        U8* url = @slon_strnew(session, scratch_buffer);

        // Mona lets us post with:                  id, created_at, content, visibility, uri, url, account, application
        // Mastodon iOS app lets us post with +:    reblogs_count, favourites_count, emojis, tags, mentions
        // IceCubesApp lets us post with +:         media_attachments, replies_count, spoiler_text, sensitive

        JsonObject* status = Json.CreateObject();
        JsonArray* media_attachments = NULL;
        status->set("id", id, JSON_STRING);
        status->set("created_at", created_at, JSON_STRING);
        status->set("content", request_json->@("status"), JSON_STRING);
        status->set("visibility", visibility, JSON_STRING);
        status->set("uri", uri, JSON_STRING);
        status->set("url", url, JSON_STRING);
        status->set("account", account_object, JSON_OBJECT);
        status->set("application", status_app, JSON_OBJECT);
        status->set("reblogs_count", 0, JSON_NUMBER);
        status->set("favourites_count", 0, JSON_NUMBER);
        status->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        status->set("tags", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        status->set("mentions", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        if (request_json->@("media_ids") && request_json->a("media_ids")->length) {
            I64 i;
            media_attachments = Json.CreateArray();
            for (i = 0; i < request_json->a("media_ids")->length; i++) {
                U8* media_id = request_json->a("media_ids")->@(i);
                if (media_id && db->o("media")->o(media_id)) {
                    media_attachments->append(Json.CreateItem(db->o("media")->o(media_id), JSON_OBJECT));
                }
            }
            status->set("media_attachments", media_attachments, JSON_ARRAY);
        } else {
            status->set("media_attachments", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
        }
        status->set("replies_count", 0, JSON_NUMBER);
        status->set("spoiler_text", "", JSON_STRING);
        status->set("sensitive", sensitive, JSON_BOOLEAN);

        if (StrLen(in_reply_to_id) > 0) {
            status->set("in_reply_to_id", in_reply_to_id, JSON_STRING);
        }

        if (!idempotency_key_already_seen) {
            db->o("statuses")->a(account_id)->append(Json.CreateItem(status, JSON_OBJECT));
            db->o("timelines")->a("public")->append(Json.CreateItem(status, JSON_OBJECT));
            @slon_db_save_statuses_to_disk;
            @slon_db_save_timelines_to_disk;
            @slon_db_instance_increment_status_count;
            @slon_db_save_instance_to_disk;
            if (@slon_api_status_create_fedi) {
                @slon_api_status_create_fedi(Json.Clone(status));
            }
        }

        session->send(status);

        if (media_attachments) {
            Json.Delete(media_attachments);
        }
        Json.Delete(status_app);
        Json.Delete(account_object);
        Json.Delete(app_object);

        @slon_free(session, uri);
        @slon_free(session, url);
        @slon_free(session, id);
        @slon_free(session, created_at);
    } else {
        session->status(401);
    }
}
