if (!StrICmp("/api/v1/bookmarks", @slon_http_request_path(session))) {
    @slon_api_v1_bookmarks_get(session);
    return;
}
