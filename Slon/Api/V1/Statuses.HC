U0 (*@slon_api_status_create_fedi)(JsonObject* status) = NULL;
U0 (*@slon_api_status_delete_fedi)(JsonObject* status) = NULL;

JsonArray* @slon_api_v1_statuses_find_descendants_by_id(U8* id)
{
    if (!id) {
        return NULL;
    }

    JsonArray* arr = Json.CreateArray(slon_mem_task);
    JsonObject* status = NULL;
    JsonKey* key = db->o("statuses")->keys;
    while (key) {
        status = @slon_api_status_lookup_by_in_reply_to_id(id, key->value);
        if (status) {
            arr->append(status);
        }
        key = key->next;
    }
    return arr;
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

    Bool only_media = @slon_api_get_value_as_boolean(request_json->@("only_media", TRUE));
    Bool exclude_replies = @slon_api_get_value_as_boolean(request_json->@("exclude_replies", TRUE));
    Bool exclude_reblogs = @slon_api_get_value_as_boolean(request_json->@("exclude_reblogs", TRUE));
    Bool pinned = @slon_api_get_value_as_boolean(request_json->@("pinned", TRUE));

    no_warn exclude_reblogs;
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
    JsonArray* statuses = Json.CreateArray(slon_mem_task);
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
            if (only_media && !status->a("media_attachments")->length) {
                exclude_status = TRUE;
            }
            if (exclude_replies && StrLen(status->@("in_reply_to_acct_id")) > 0 && StrICmp(account_id, status->@("in_reply_to_acct_id"))) {
                exclude_status = TRUE;
            }
            if (pinned && !status->@("pinned")) {
                exclude_status = TRUE;
            }
            if (!exclude_status) {
                statuses->append(status);
                count++;
            }
            if (limit > 0 && count >= limit) {
                break;
            }
        }
    }
    session->send(statuses);
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
                fedi_status = Json.Clone(status, slon_mem_task);
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
                            Spawn(&@slon_api_async_delete_from_catbox, StrNew(attachment_url_ptr, slon_mem_task), "SlonAsyncCatboxDelete");
                        }
                    }
                }
                @slon_db_save_status_to_disk(status);
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

        if (session->path_count() > 4 && !StrICmp("context", session->path(4))) {
            JsonObject* context = Json.CreateObject(slon_mem_task);
            context->set("ancestors", Json.CreateArray(slon_mem_task), JSON_ARRAY);

            // Get ancestors
            id = session->path(3);
            status = @slon_api_find_status_by_id(id, NULL);
            while (status && status->@("in_reply_to_id")) {
                status = @slon_api_find_status_by_id(status->@("in_reply_to_id"), status->@("in_reply_to_acct_id"));
                if (status) {
                    context->a("ancestors")->append(status);
                }
            }

            // Get descendants
            id = session->path(3);
            context->set("descendants", @slon_api_v1_statuses_find_descendants_by_id(id), JSON_ARRAY);

            session->send(context);
            return;
        }

        status = @slon_api_find_status_by_id(id, NULL);
        if (status) {
            session->send(status);
            return;
        }
        session->status(404);
    } else {
        status = @slon_api_find_status_by_id(id, NULL);
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

        U8* id = NULL;

        if (session->path_count() > 4) {
            // FIXME: Do stuff
            AdamLog("session->path_count is : %d\n", session->path_count());
            session->status(404);
            return;
        }

        Bool idempotency_key_already_seen = FALSE;
        U8* idempotency_key = session->header("idempotency-key");
        if (StrLen(idempotency_key) > 0 && db->o("idempotency_keys")->@(idempotency_key)) {
            idempotency_key_already_seen = TRUE;
        }
        if (!idempotency_key_already_seen) {
            db->o("idempotency_keys")->set(idempotency_key, Now, JSON_NUMBER);
        }

        id = @slon_api_generate_unique_id(session);
        U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

        JsonObject* app_object = db->o("apps")->@(session->auth->@("client_id"));

        JsonObject* status_app = Json.CreateObject(slon_mem_task);
        status_app->set("name", app_object->@("name"), JSON_STRING);
        status_app->set("website", app_object->@("website"), JSON_STRING);

        JsonObject* account_object = Json.Clone(@slon_api_account_by_id(account_id), slon_mem_task);
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

        JsonObject* status = Json.CreateObject(slon_mem_task);
        JsonObject* reply_to_status = NULL;
        JsonArray* media_attachments = NULL;
        String.Trim(request_json->@("status"));
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
            media_attachments = Json.CreateArray(slon_mem_task);
            for (i = 0; i < request_json->a("media_ids")->length; i++) {
                U8* media_id = request_json->a("media_ids")->@(i);
                if (media_id && db->o("media")->o(media_id)) {
                    media_attachments->append(db->o("media")->o(media_id));
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
            reply_to_status = @slon_api_find_status_by_id(in_reply_to_id);
            if (reply_to_status) {
                status->set("in_reply_to_acct_id", reply_to_status->o("account")->@("id"), JSON_STRING);
            }
        }

        if (!idempotency_key_already_seen) {
            @slon_api_create_status(status, account_id);
            if (@slon_api_status_create_fedi) {
                @slon_api_status_create_fedi(Json.Clone(status, slon_mem_task));
            }
        }

        session->send(status);

        @slon_free(session, uri);
        @slon_free(session, url);
        @slon_free(session, id);
        @slon_free(session, created_at);
    } else {
        session->status(401);
    }
}
