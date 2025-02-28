U0 @slon_api_v1_markers_get(SlonHttpSession* session)
{
    if (!@slon_api_authorized(session)) {
        session->status(401);
        return;
    }

    SLON_AUTH_ACCOUNT_ID

    if (db->o("markers")->@(account_id)) {
        session->send(db->o("markers")->@(account_id));
    } else {
        session->send(SLON_EMPTY_JSON_OBJECT);
    }
}

U0 @slon_api_v1_markers_post(SlonHttpSession* session)
{
    if (!@slon_api_authorized(session)) {
        session->status(401);
        return;
    }

    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    SLON_AUTH_ACCOUNT_ID

    U8* updated_at = @slon_api_timestamp_from_cdate(session, Now);

    JsonKey* key = request_json->keys;
    JsonObject* obj = NULL;
    I64 version = cnts.jiffies;
    while (key) {
        obj = key->value;
        if (obj) {
            obj->set("version", version, JSON_NUMBER);
            obj->set("updated_at", updated_at, JSON_STRING);
        }
        key = key->next;
    }

    db->o("markers")->set(account_id, request_json, JSON_OBJECT);
    @slon_db_save_markers_to_disk;

    session->send(request_json);
    @slon_free(session, updated_at);
}
