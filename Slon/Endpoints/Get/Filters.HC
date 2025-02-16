if (!StrICmp("/api/v1/filters", @slon_http_request_path(session))) {
    @slon_api_v1_filters_get(session);
    return;
}

if (!StrICmp("/api/v2/filters", @slon_http_request_path(session))) {
    @slon_api_v2_filters_get(session);
    return;
}
