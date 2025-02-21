if (!StrICmp("/api/v1/follow_requests", session->path())) {
    @slon_api_v1_follow_requests_get(session);
    return;
}
