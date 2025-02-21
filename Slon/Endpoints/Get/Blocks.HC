if (!StrICmp("/api/v1/blocks", session->path())) {
    @slon_api_v1_blocks_get(session);
    return;
}
