U0 @slon_api_v1_timelines_home(SlonHttpSession* session, U8* account_id)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    // Return the Account's Home timeline
    JsonArray* status_array = db->o("timelines")->o("home")->a(account_id);
    if (!status_array) {
        @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
        return;
    }

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
        I64 i;
        for (i = 0; i < status_array->length; i++) {
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

    @slon_http_send_json(session, statuses);

    Json.Delete(statuses);
}

U0 @slon_api_v1_timelines_get(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        U8* path = @slon_strnew(session, @slon_http_request_path(session));
        I64 path_segments_count = 0;
        U8** path_segments = String.Split(path, '/', &path_segments_count);

        if (path_segments_count < 4) {
            goto slon_api_v1_timelines_get_return;
        }

        if (!StrICmp("public", path_segments[3])) {
            // FIXME: Implement this
            @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
            goto slon_api_v1_timelines_get_return;
        }

        if (!StrICmp("tag", path_segments[3])) {
            // FIXME: Implement this
            @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
            goto slon_api_v1_timelines_get_return;
        }

        if (!StrICmp("home", path_segments[3])) {
            // FIXME: Implement this
            @slon_api_v1_timelines_home(session, account_id);
            goto slon_api_v1_timelines_get_return;
        }

        if (!StrICmp("link", path_segments[3])) {
            // FIXME: Implement this
            @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
            goto slon_api_v1_timelines_get_return;
        }

        if (!StrICmp("list", path_segments[3])) {
            // FIXME: Implement this
            @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
            goto slon_api_v1_timelines_get_return;
        }

        @slon_http_set_status_code(session, 404);
    } else {
        @slon_http_set_status_code(session, 401);
    }
slon_api_v1_timelines_get_return:
    Free(path_segments);
    @slon_free(session, path);
}
