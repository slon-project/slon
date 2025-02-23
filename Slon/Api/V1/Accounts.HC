U0 (*@slon_api_follow_fedi)(JsonObject* follow) = NULL;
extern U0 @slon_api_v1_statuses_query(SlonHttpSession* session, JsonArray* status_array);

U0 @slon_api_v1_accounts_follow_request(U8* this_actor, U8* remote_actor)
{
    U8 scratch_buffer[1024];
    StrPrint(scratch_buffer, "%s/follow/%d", this_actor, Now);
    JsonObject* follow_object = Json.CreateObject();
    follow_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    follow_object->set("id", scratch_buffer, JSON_STRING);
    follow_object->set("type", "Follow", JSON_STRING);
    follow_object->set("actor", this_actor, JSON_STRING);
    follow_object->set("object", remote_actor, JSON_STRING);
    if (@slon_api_follow_fedi) {
        @slon_api_follow_fedi(follow_object);
    } else {
        Json.Delete(follow_object);
    }
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

    if (2 == 3) {
        // placeholder for other methods
    } else {
        // Work with account :id
        U8* some_account_id = session->path(3);
        JsonObject* acct = @slon_api_account_by_id(some_account_id);
        if (!acct) {
            session->status(404);
            return;
        }
        if (session->path_count() > 5) {
            U8* method = session->path(4);
            if (!StrICmp("follow", method)) {
                if (!acct->@("remote_actor")) {
                    session->status(404);
                    return;
                }
                // add to my following
                if (!db->o("following")->a(my_acct->@("username"))) {
                    db->o("following")->set(my_acct->@("username"), Json.CreateArray(), JSON_ARRAY);
                }
                db->o("following")->a(my_acct->@("username"))->append(Json.CreateItem(acct->@("remote_actor"), JSON_STRING));
                @slon_db_save_following_to_disk;
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
                return;
            }
            session->status(404);
        } else {
            session->status(404);
        }
    }
}

U0 @slon_api_v1_accounts_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    I64 i;

    JsonObject* acct = NULL;
    if (!StrICmp("relationships", session->path(3))) {
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
            return;
        } else {
            session->status(401);
        }
    } else if (!StrICmp("verify_credentials", session->path(3))) {
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
        U8* some_account_id = session->path(3);
        acct = @slon_api_account_by_id(some_account_id);
        if (!acct) {
            session->status(404);
            return;
        }
        if (session->path_count() > 5) {
            U8* method = session->path(4);
            if (!StrICmp("following", method)) {
                // FIXME: Implement this
                session->send(SLON_EMPTY_JSON_ARRAY);
                return;
            }
            if (!StrICmp("statuses", method)) {
                // Return the Account's Statuses
                @slon_api_v1_statuses_query(session, db->o("statuses")->a(some_account_id));
                return;
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
}

Bool @slon_api_v1_accounts_key_is_boolean(U8* name)
{
    return (!StrICmp(name, "locked") || !StrICmp(name, "bot") || !StrICmp(name, "discoverable") || !StrICmp(name, "hide_collections") || !StrICmp(name, "indexable"));
}

U0 @slon_api_v1_accounts_patch(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    JsonObject* acct = NULL;

    if (!StrICmp("update_credentials", session->path(3))) {
        if (@slon_api_authorized(session)) {
            SLON_AUTH_ACCOUNT_ID

            if (!request_json || !request_json->keys) {
                session->status(400);
                return;
            }

            // FIXME: Support avatars/banners
            acct = @slon_api_account_by_id(account_id);
            if (!acct) {
                session->status(404);
                return;
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
}
