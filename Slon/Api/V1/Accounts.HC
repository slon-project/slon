U0 @slon_api_v1_accounts_follow_request(U8* this_actor, U8* remote_actor)
{

    U8 scratch_buffer[2048];

    StrPrint(scratch_buffer, "%s/follow/%d", this_actor, Now);
    JsonObject* follow_object = Json.CreateObject();
    follow_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    follow_object->set("id", scratch_buffer, JSON_STRING);
    follow_object->set("type", "Follow", JSON_STRING);
    follow_object->set("actor", this_actor, JSON_STRING);
    follow_object->set("object", remote_actor, JSON_STRING);

    U8* follow_object_s = Json.Stringify(follow_object);

    U8 content_hash[512];
    calc_sha_256(content_hash, follow_object_s, StrLen(follow_object_s));
    U8* computed_digest = @base64_encode(content_hash, 32);

    JsonObject* http_headers = Json.CreateObject();

    StrPrint(scratch_buffer, "%s/inbox", remote_actor);
    HttpUrl* url = @http_parse_url(scratch_buffer);

    CDateStruct ds;
    Date2Struct(&ds, Now + 1043910000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
    http_headers->set("Digest", scratch_buffer, JSON_STRING);

    http_headers->set("Content-Type", "application/activity+json", JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): post %s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s\n", http_headers->@("Date"));
    String.Append(scratch_buffer, "digest: %s\n", http_headers->@("Digest"));
    String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);

    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", this_actor) + 7;
    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject();
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", this_actor);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date digest content-type\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    @http_response* resp = Http.Post(url, fetch_buffer, follow_object_s, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not POST Accept, invalid response from remote server");
        Free(fetch_buffer);
        return;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    AdamLog("code: %d\n", resp->status.code);

    Free(fetch_buffer);
}

U0 @slon_api_v1_accounts_post(SlonHttpSession* session)
{
    if (!@slon_api_authorized(session)) {
        session->status(401);
        return;
    }

    SLON_AUTH_ACCOUNT_ID
    JsonObject* my_acct = @slon_api_account_by_id(account_id);

    I64 i;

    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);

    if (2 == 3) {
        // placeholder for other methods
    } else {
        // Work with account :id
        U8* some_account_id = path_segments[3];
        JsonObject* acct = @slon_api_account_by_id(some_account_id);
        if (!acct) {
            session->status(404);
            goto slon_api_v1_accounts_post_return;
        }
        if (path_segments_count > 5) {
            U8* method = path_segments[4];
            if (!StrICmp("follow", method)) {
                if (!acct->@("remote_actor")) {
                    session->status(404);
                    goto slon_api_v1_accounts_post_return;
                }
                // add to my following
                if (!db->o("following")->a(my_acct->@("username"))) {
                    db->o("following")->set(my_acct->@("username"), Json.CreateArray(), JSON_ARRAY);
                }
                db->o("following")->a(my_acct->@("username"))->append(Json.CreateItem(acct->@("remote_actor"), JSON_STRING));
                @slon_db_save_to_disk;
                // send Follow request
                @slon_api_v1_accounts_follow_request(db->o("actors")->o((my_acct->@("username")))->@("id"), acct->@("remote_actor"));

                Bool followed_by = FALSE;
                JsonArray* my_followers = db->o("followers")->a(my_acct->@("username"));
                if (my_followers) {
                    for (i = 0; i < my_followers->length; i++) {
                        if (my_followers->@(i) && !StrICmp(my_followers->@(i), acct->@("remote_actor"))) {
                            followed_by = TRUE;
                            break;
                        }
                    }
                }
                JsonObject* relationship = Json.CreateObject();
                relationship->set("id", acct->@("id"), JSON_STRING);
                relationship->set("following", TRUE, JSON_BOOLEAN);
                relationship->set("showing_reblogs", TRUE, JSON_BOOLEAN);
                relationship->set("notifying", FALSE, JSON_BOOLEAN);
                relationship->set("followed_by", followed_by, JSON_BOOLEAN);
                relationship->set("blocking", FALSE, JSON_BOOLEAN);
                relationship->set("blocked_by", FALSE, JSON_BOOLEAN);
                relationship->set("muting", FALSE, JSON_BOOLEAN);
                relationship->set("muting_notifications", FALSE, JSON_BOOLEAN);
                relationship->set("requested", FALSE, JSON_BOOLEAN);
                relationship->set("domain_blocking", FALSE, JSON_BOOLEAN);
                relationship->set("endorsed", FALSE, JSON_BOOLEAN);
                session->send(relationship);
                goto slon_api_v1_accounts_post_return;
            }
            session->status(404);
        } else {
            session->status(404);
        }
    }
slon_api_v1_accounts_post_return:
    @slon_free(session, path);
}

U0 @slon_api_v1_accounts_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    I64 i;

    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);

    JsonObject* acct = NULL;
    if (!StrICmp("relationships", path_segments[3])) {
        if (@slon_api_authorized(session)) {
            // FIXME: handle array of id[]=

            JsonArray* relationships = Json.CreateArray();
            if (request_json->@("id%5B%5D")) {
                JsonObject* target_account = @slon_api_account_by_id(request_json->@("id%5B%5D"));
                if (target_account) {
                    Bool followed_by = FALSE;
                    Bool following = FALSE;
                    if (target_account->@("remote_actor")) {
                        JsonObject* my_account = @slon_api_account_by_id(Json.Get(session->auth, "account_id"));
                        JsonArray* my_followers = db->o("followers")->a(my_account->@("username"));
                        if (my_followers) {
                            for (i = 0; i < my_followers->length; i++) {
                                if (my_followers->@(i) && !StrICmp(my_followers->@(i), target_account->@("remote_actor"))) {
                                    followed_by = TRUE;
                                    break;
                                }
                            }
                        }
                        JsonArray* my_following = db->o("following")->a(my_account->@("username"));
                        if (my_following) {
                            for (i = 0; i < my_following->length; i++) {
                                if (my_following->@(i) && !StrICmp(my_following->@(i), target_account->@("remote_actor"))) {
                                    following = TRUE;
                                    break;
                                }
                            }
                        }
                    }
                    JsonObject* relationship = Json.CreateObject();
                    relationship->set("id", target_account->@("id"), JSON_STRING);
                    relationship->set("following", following, JSON_BOOLEAN);
                    relationship->set("showing_reblogs", TRUE, JSON_BOOLEAN);
                    relationship->set("notifying", FALSE, JSON_BOOLEAN);
                    relationship->set("followed_by", followed_by, JSON_BOOLEAN);
                    relationship->set("blocking", FALSE, JSON_BOOLEAN);
                    relationship->set("blocked_by", FALSE, JSON_BOOLEAN);
                    relationship->set("muting", FALSE, JSON_BOOLEAN);
                    relationship->set("muting_notifications", FALSE, JSON_BOOLEAN);
                    relationship->set("requested", FALSE, JSON_BOOLEAN);
                    relationship->set("domain_blocking", FALSE, JSON_BOOLEAN);
                    relationship->set("endorsed", FALSE, JSON_BOOLEAN);
                    relationships->append(Json.CreateItem(relationship, JSON_OBJECT));
                }
            }

            session->send(relationships);
            Json.Delete(relationships);
            goto slon_api_v1_accounts_get_return;
        } else {
            session->status(401);
        }
    } else if (!StrICmp("verify_credentials", path_segments[3])) {
        if (@slon_api_authorized(session)) {
            SLON_AUTH_ACCOUNT_ID
            acct = @slon_api_account_by_id(account_id);
            if (acct) {
                session->send(acct);
            } else {
                session->status(404);
            }
        } else {
            session->status(401);
        }
    } else {
        // Work with account :id
        U8* some_account_id = path_segments[3];
        acct = @slon_api_account_by_id(some_account_id);
        if (!acct) {
            session->status(404);
            goto slon_api_v1_accounts_get_return;
        }
        if (path_segments_count > 5) {
            U8* method = path_segments[4];
            if (!StrICmp("following", method)) {
                // FIXME: Implement this
                session->send(SLON_EMPTY_JSON_ARRAY);
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
                goto slon_api_v1_accounts_get_return;
            }
            session->status(404);
        } else {
            // Return the Account profile
            JsonObject* profile_object = Json.Clone(acct);
            profile_object->unset("source");
            session->send(profile_object);
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
                session->status(400);
                goto slon_api_v1_accounts_patch_return;
            }

            // FIXME: Support avatars/banners
            acct = @slon_api_account_by_id(account_id);
            if (!acct) {
                session->status(404);
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
            session->send(acct);
        } else {
            session->status(401);
        }
    } else {
        session->status(404);
    }
slon_api_v1_accounts_patch_return:
    @slon_free(session, path);
}
