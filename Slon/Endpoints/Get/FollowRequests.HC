if (!StrICmp("/api/v1/follow_requests", @slon_http_request_path(session))) {
    @slon_api_v1_follow_requests_get(session);
    return;
}
