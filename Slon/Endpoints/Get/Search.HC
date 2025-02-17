if (!StrICmp("/api/v2/search", @slon_http_request_path(session))) {
    @slon_api_v2_search_get(session);
    return;
}
