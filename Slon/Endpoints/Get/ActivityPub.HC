if (String.BeginsWith("/users/", session->path()) && StrFind("json", session->header("accept"))) {
    @slon_activitypub_users_get(session);
    return;
}
