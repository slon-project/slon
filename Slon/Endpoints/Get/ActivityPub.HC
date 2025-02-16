if (String.BeginsWith("/users/", @slon_http_request_path(session)) && String.EndsWith("json", @slon_http_request_header(session, "accept"))) {
    @slon_activitypub_users_get(session);
    return;
}
