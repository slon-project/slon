if (!StrICmp("/api/v1/followed_tags", session->path())) {
    @slon_api_v1_followed_tags_get(session);
    return;
}
