if (String.BeginsWith("/users/", session->path()) && !StrICmp("json", session->header("accept"))) {
    @slon_activitypub_users_get(session);
    return;
}
