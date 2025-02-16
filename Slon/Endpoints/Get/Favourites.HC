if (!StrICmp("/api/v1/favourites", @slon_http_request_path(session))) {
    @slon_api_v1_favourites_get(session);
    return;
}
