U0 @slon_api_v1_notifications_get(SlonHttpSession* session)
{
    // SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        // SLON_AUTH_ACCOUNT_ID
        // FIXME: Implement this
        if (String.EndsWith("policy", session->path())) {
            session->send(SLON_EMPTY_JSON_OBJECT);
        } else {
            session->send(SLON_EMPTY_JSON_ARRAY);
        }
    } else {
        session->status(401);
    }
}
