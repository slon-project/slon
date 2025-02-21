if (!StrICmp("/api/v1/custom_emojis", session->path())) {
    @slon_api_v1_custom_emojis_get(session);
    return;
}
