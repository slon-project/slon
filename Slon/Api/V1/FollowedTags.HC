U0 @slon_api_v1_followed_tags_get(SlonHttpSession* session)
{
    // SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        // SLON_AUTH_ACCOUNT_ID
        // FIXME: Implement this
        @slon_http_send_json(session, SLON_EMPTY_JSON_ARRAY);
    } else {
        session->status(401);
    }
}
