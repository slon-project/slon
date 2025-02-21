if (String.BeginsWith("/users/", session->path())) {
    @slon_activitypub_users_post(session);
    return;
}
