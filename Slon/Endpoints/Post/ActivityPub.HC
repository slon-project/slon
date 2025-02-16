if (String.BeginsWith("/users/", @slon_http_request_path(session))) {
    @slon_activitypub_users_post(session);
    return;
}
