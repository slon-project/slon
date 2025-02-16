if (!StrICmp("/api/v1/custom_emojis", @slon_http_request_path(session))) {
    @slon_api_v1_custom_emojis_get(session);
    return;
}
