if (!StrICmp("/api/v1/followed_tags", @slon_http_request_path(session))) {
    @slon_api_v1_followed_tags_get(session);
    return;
}
