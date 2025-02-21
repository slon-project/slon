if (!StrICmp("/api/v1/conversations", session->path())) {
    @slon_api_v1_conversations_get(session);
    return;
}
