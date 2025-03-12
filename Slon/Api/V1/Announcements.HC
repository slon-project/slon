// Internally, "reactions" is stored as { "emoji": [ "account_id", "account_id", ...]}
// This is presented to the client as: "reactions": [{ "name": "emoji", "count": (count), "me": (true|false) }, ...]

U0 @slon_api_v1_announcements_delete(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        if (session->path_count() < 6) {
            session->status(400);
            return;
        }

        I64 i;
        U8* id = session->path(3);
        U8* verb = session->path(4);
        U8* emoji = @slon_http_decode_urlencoded_string(session, session->path(5));

        JsonObject* announcement = @slon_api_announcement_by_id(id);
        if (!announcement) {
            @slon_free(session, emoji);
            session->status(404);
            return;
        }

        if (!StrICmp("reactions", verb)) {
            JsonArray* emoji_array = announcement->o("reactions")->a(emoji);
            Bool save_announcements = FALSE;
            if (emoji_array && emoji_array->contains(account_id)) {
                for (i = 0; i < emoji_array->length; i++) {
                    if (!StrICmp(account_id, emoji_array->@(i))) {
                        emoji_array->remove(i);
                        if (!emoji_array->length) {
                            announcement->o("reactions")->unset(emoji);
                        }
                        @slon_db_save_announcements_to_disk;
                        break;
                    }
                }
            }
        }
        @slon_free(session, emoji);
        session->send(SLON_EMPTY_JSON_OBJECT);
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_announcements_get(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        JsonArray* announcements = Json.CreateArray(session->mem_task);
        JsonArray* iter_array = db->a("announcements");
        JsonObject* announcement = NULL;
        JsonKey* reaction_key = NULL;
        JsonObject* reaction_object = NULL;

        I64 i;
        for (i = 0; i < iter_array->length; i++) {
            announcement = Json.Clone(iter_array->o(i), session->mem_task);
            if (announcement->a("read_users")->contains(account_id)) {
                announcement->set("read", TRUE, JSON_BOOLEAN);
            }
            announcement->unset("read_users");
            JsonArray* reactions_array = Json.CreateArray(session->mem_task);
            reaction_key = announcement->o("reactions")->keys;
            while (reaction_key) {
                reaction_object = Json.CreateObject(session->mem_task);
                reaction_object->set("name", reaction_key->name, JSON_STRING);
                reaction_object->set("count", reaction_key->value(JsonArray*)->length, JSON_NUMBER);
                reaction_object->set("me", reaction_key->value(JsonArray*)->contains(account_id), JSON_BOOLEAN);
                reactions_array->append(reaction_object);
                reaction_key = reaction_key->next;
            }
            announcement->set("reactions", reactions_array, JSON_ARRAY);

            announcements->append(announcement);
        }

        session->send(announcements);
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_announcements_post(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        if (session->path_count() < 5) {
            session->status(400);
            return;
        }

        U8* id = session->path(3);
        U8* verb = session->path(4);

        JsonObject* announcement = @slon_api_announcement_by_id(id);
        if (!announcement) {
            session->status(404);
            return;
        }

        if (!StrICmp("dismiss", verb)) {
            if (!announcement->a("read_users")->contains(account_id)) {
                announcement->a("read_users")->append(account_id);
                @slon_db_save_announcements_to_disk;
            }
        }

        session->send(SLON_EMPTY_JSON_OBJECT);
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_announcements_put(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        if (session->path_count() < 6) {
            session->status(400);
            return;
        }

        U8* id = session->path(3);
        U8* verb = session->path(4);
        U8* emoji = @slon_http_decode_urlencoded_string(session, session->path(5));

        JsonObject* announcement = @slon_api_announcement_by_id(id);
        if (!announcement) {
            @slon_free(session, emoji);
            session->status(404);
            return;
        }

        if (!StrICmp("reactions", verb)) {
            JsonArray* emoji_array = announcement->o("reactions")->a(emoji);
            Bool save_announcements = FALSE;
            if (!emoji_array) {
                emoji_array = Json.CreateArray(slon_db_mem_task);
                announcement->o("reactions")->set(emoji, emoji_array, JSON_ARRAY);
                save_announcements = TRUE;
            }
            if (!emoji_array->contains(account_id)) {
                emoji_array->append(account_id);
                save_announcements = TRUE;
            }
            if (save_announcements) {
                @slon_db_save_announcements_to_disk;
            }
        }
        @slon_free(session, emoji);
        session->send(SLON_EMPTY_JSON_OBJECT);
    } else {
        session->status(401);
    }
}
