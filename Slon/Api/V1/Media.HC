U0 @slon_api_v1_media_get(SlonHttpSession* session)
{
    if (@slon_api_authorized(session)) {
        if (session->path_count() < 4) {
            session->status(400);
            return;
        }
        U8* id = session->path(3);
        if (db->o("media")->o(id)) {
            if (db->o("media")->o(id)->@("url", TRUE)(JsonKey*)->type == JSON_NULL) {
                session->send(db->o("media")->o(id));
                session->status(206);
            } else {
                session->send(db->o("media")->o(id));
            }
        } else {
            session->status(404);
        }
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_media_put(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (@slon_api_authorized(session)) {
        if (session->path_count() < 4) {
            session->status(400);
            return;
        }
        U8* id = session->path(3);
        if (db->o("media")->@(id)) {
            db->o("media")->o(id)->set("description", request_json->@("description"), JSON_STRING);
            session->send(db->o("media")->o(id));
        } else {
            session->status(404);
        }
    } else {
        session->status(401);
    }
}
