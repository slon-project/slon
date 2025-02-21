if (!StrICmp("/api/v1/bookmarks", session->path())) {
    @slon_api_v1_bookmarks_get(session);
    return;
}
