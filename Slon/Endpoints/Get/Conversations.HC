if (!StrICmp("/api/v1/conversations", @slon_http_request_path(session))) {
    @slon_api_v1_conversations_get(session);
    return;
}
