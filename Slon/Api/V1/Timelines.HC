U0 @slon_api_v1_timelines_home(SlonHttpSession* session, U8* account_id)
{
    // Return the Account's Home timeline
    @slon_api_v1_statuses_query(session, @slon_api_status_array_from_timeline(db->o("timelines")->o("home")->a(account_id)));
}

U0 @slon_api_v1_timelines_public(SlonHttpSession* session)
{
    // Return the Public timeline
    @slon_api_v1_statuses_query(session, @slon_api_status_array_from_timeline(db->o("timelines")->a("public")));
}

U0 @slon_api_v1_timelines_get(SlonHttpSession* session)
{
    U8* timeline = session->path(3);
    if (!StrICmp("public", timeline)) {
        @slon_api_v1_timelines_public(session);
        return;
    }
    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        if (session->path_count() < 4) {
            return;
        }
        if (!StrICmp("tag", timeline)) {
            // FIXME: Implement this
            session->send(SLON_EMPTY_JSON_ARRAY);
            return;
        }
        if (!StrICmp("home", timeline)) {
            // FIXME: Implement this
            @slon_api_v1_timelines_home(session, account_id);
            return;
        }
        if (!StrICmp("link", timeline)) {
            // FIXME: Implement this
            session->send(SLON_EMPTY_JSON_ARRAY);
            return;
        }
        if (!StrICmp("list", timeline)) {
            // FIXME: Implement this
            session->send(SLON_EMPTY_JSON_ARRAY);
            return;
        }
        session->status(404);
    } else {
        session->status(401);
        return;
    }
}
