if (!StrICmp("/api/v1/blocks", @slon_http_request_path(session))) {
    @slon_api_v1_blocks_get(session);
    return;
}
