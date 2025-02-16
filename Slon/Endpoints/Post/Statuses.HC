if (!StrICmp("/api/v1/statuses", @slon_http_request_path(session))) {
    @slon_api_v1_statuses_post(session);
    return;
}
