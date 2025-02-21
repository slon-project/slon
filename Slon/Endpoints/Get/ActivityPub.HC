if (String.BeginsWith("/users/", session->path()) && String.EndsWith("json", session->header("accept"))) {
    @slon_activitypub_users_get(session);
    return;
}
