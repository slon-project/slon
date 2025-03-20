U0 @slon_api_v1_notifications_get(SlonHttpSession* session)
{
    // SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        JsonObject* acct = @slon_api_account_by_id(account_id);

        if (String.EndsWith("policy", session->path())) {
            session->send(SLON_EMPTY_JSON_OBJECT);
        } else {
            if (!db->o("notifications")->@(acct->@("username"))) {
                db->o("notifications")->set(acct->@("username"), Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
            }
            session->send(db->o("notifications")->a(acct->@("username")));
        }
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_notifications_post(SlonHttpSession* session)
{
    // SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        JsonObject* acct = @slon_api_account_by_id(account_id);

        if (String.EndsWith("/clear", session->path())) {
            db->o("notifications")->set(acct->@("username"), Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
            @slon_db_save_notifications_to_disk;
            session->send(SLON_EMPTY_JSON_OBJECT);
        } else {
            session->send(400);
        }
    } else {
        session->status(401);
    }
}
