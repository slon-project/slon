U0 (*@slon_api_status_create_fedi)(JsonObject* status) = NULL;
U0 (*@slon_api_status_delete_fedi)(JsonObject* status) = NULL;

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

        I64 i;
        for (i = 0; i < statuses->length; i++) {
            status = statuses->@(i);
            if (!StrICmp(status->@("id"), id)) {
                fedi_status = Json.Clone(status);
                status->set("deleted", TRUE, JSON_BOOLEAN);
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
        status->set("media_attachments", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
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
