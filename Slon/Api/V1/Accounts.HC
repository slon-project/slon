U0 @slon_api_v1_accounts_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);

    JsonObject* acct = NULL;

    if (!StrICmp("verify_credentials", path_segments[3])) {
        if (@slon_api_authorized(session)) {
            SLON_AUTH_ACCOUNT_ID
            acct = @slon_api_account_by_id(account_id);
            if (acct) {
                @slon_http_send_json(session, acct);
            } else {
                @slon_http_set_status_code(session, 404);
            }
        } else {
            @slon_http_set_status_code(session, 401);
        }
    } else {
        // Work with account :id
        U8* some_account_id = path_segments[3];
        acct = @slon_api_account_by_id(some_account_id);
        if (!acct) {
            @slon_http_set_status_code(session, 404);
            goto slon_api_v1_accounts_get_return;
        }
        if (path_segments_count > 5) {
            U8* method = path_segments[4];
            if (!StrICmp("following", method)) {
                // FIXME: Implement this
                @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
                goto slon_api_v1_accounts_get_return;
            }
            if (!StrICmp("statuses", method)) {
                // Return the Account's Statuses
                JsonArray* status_array = db->o("statuses")->a(some_account_id);

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
                goto slon_api_v1_accounts_get_return;
            }
            @slon_http_set_status_code(session, 404);
        } else {
            // Return the Account profile
            JsonObject* profile_object = Json.Clone(acct);
            profile_object->unset("source");
            @slon_http_send_json(session, profile_object);
            Json.Delete(profile_object);
        }
    }
slon_api_v1_accounts_get_return:
    @slon_free(session, path);
}

Bool @slon_api_v1_accounts_key_is_boolean(U8* name)
{
    return (!StrICmp(name, "locked") || !StrICmp(name, "bot") || !StrICmp(name, "discoverable") || !StrICmp(name, "hide_collections") || !StrICmp(name, "indexable"));
}

U0 @slon_api_v1_accounts_patch(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);

    JsonObject* acct = NULL;

    if (!StrICmp("update_credentials", path_segments[3])) {
        if (@slon_api_authorized(session)) {
            SLON_AUTH_ACCOUNT_ID

            if (!request_json || !request_json->keys) {
                @slon_http_set_status_code(session, 400);
                goto slon_api_v1_accounts_patch_return;
            }

            // FIXME: Support avatars/banners
            acct = @slon_api_account_by_id(account_id);
            if (!acct) {
                @slon_http_set_status_code(session, 404);
                goto slon_api_v1_accounts_patch_return;
            }
            JsonObject* source = acct->@("source");

            I64 fields_attributes_indexes[16];
            I64 fields_attributes_count = 0;
            U8* field_name;
            U8* field_value;
            JsonKey* update_field_index;
            JsonObject* field_object;
            Bool update_fields_from_form_data = FALSE;
            Bool integer_is_in_index = FALSE;

            I64 i;
            I64 index;
            MemSet(fields_attributes_indexes, NULL, sizeof(I64) * 16);
            JsonArray* fields_array = Json.CreateArray();

            JsonKey* key = request_json->keys;
            while (key) {
                if (!String.BeginsWith("fields_attributes", key->name) && !String.BeginsWith("source", key->name)) {
                    if (@slon_api_v1_accounts_key_is_boolean(key->name)) {
                        switch (key->type) {
                        case JSON_STRING:
                            acct->set(key->name, @slon_api_boolean_from_string(key->value), JSON_BOOLEAN);
                            break;
                        default:
                            acct->set(key->name, key->value > 0, JSON_BOOLEAN);
                            break;
                        }
                    } else {
                        acct->set(key->name, key->value, key->type);
                    }
                } else if (String.BeginsWith("source", key->name)) {
                    if (!StrICmp("source[language]", key->name)) {
                        source->set("language", key->value);
                    }
                    if (!StrICmp("source[privacy]", key->name)) {
                        source->set("privacy", key->value);
                    }
                } else if (String.BeginsWith("fields_attributes[", key->name)) {
                    // Get fields indexes from form data
                    update_fields_from_form_data = TRUE;
                    index = Str2I64(key->name + StrLen("fields_attributes["));
                    if (!fields_attributes_count) {
                        fields_attributes_indexes[fields_attributes_count] = index;
                        ++fields_attributes_count;
                    } else {
                        integer_is_in_index = FALSE;
                        i = 0;
                        while (i < fields_attributes_count) {
                            if (index == fields_attributes_indexes[i])
                                integer_is_in_index = TRUE;
                            ++i;
                        }
                        if (!integer_is_in_index) {
                            fields_attributes_indexes[fields_attributes_count] = index;
                            ++fields_attributes_count;
                        }
                    }
                } else if (!StrICmp("fields_attributes", key->name)) {
                    // Get fields data from JSON object
                    AdamLog("let's get fields data from JSON object!!\n");
                    update_field_index = key->value(JsonObject*)->keys;
                    while (update_field_index) {
                        field_object = update_field_index->value;
                        field_object->set("verified_at", NULL, JSON_NULL);
                        AdamLog("before stringify\n");
                        AdamLog("%s\n", Json.Stringify(field_object));
                        AdamLog("after stringify\n");
                        fields_array->append(Json.CreateItem(field_object, JSON_OBJECT));
                        update_field_index = update_field_index->next;
                    }
                }
                key = key->next;
            }

            if (update_fields_from_form_data) {
                for (i = 0; i < fields_attributes_count; i++) {
                    index = fields_attributes_indexes[i];
                    field_name = NULL;
                    field_value = NULL;
                    key = request_json->keys;
                    while (key) {
                        StrPrint(scratch_buffer, "fields_attributes[%d][name]", index);
                        if (String.BeginsWith(scratch_buffer, key->name)) {
                            field_name = key->value;
                        }
                        StrPrint(scratch_buffer, "fields_attributes[%d][value]", index);
                        if (String.BeginsWith(scratch_buffer, key->name)) {
                            field_value = key->value;
                        }
                        if (field_name && field_value) {
                            // create new field_object, and append to acct->fields
                            field_object = Json.CreateObject();
                            field_object->set("name", field_name, JSON_STRING);
                            field_object->set("value", field_value, JSON_STRING);
                            field_object->set("verified_at", NULL, JSON_NULL);
                            fields_array->append(Json.CreateItem(field_object, JSON_OBJECT));
                            field_name = NULL;
                            field_value = NULL;
                        }
                        key = key->next;
                    }
                }
            }

            acct->set("fields", fields_array, JSON_ARRAY);
            source->set("fields", acct->@("fields"), JSON_ARRAY);

            @slon_db_save_accounts_to_disk;
            @slon_db_actors_update_user(acct);
            @slon_http_send_json(session, acct);
        } else {
            @slon_http_set_status_code(session, 401);
        }
    } else {
        @slon_http_set_status_code(session, 404);
    }
slon_api_v1_accounts_patch_return:
    @slon_free(session, path);
}
