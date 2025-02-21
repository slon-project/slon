if (!StrICmp("/api/v2/search", session->path())) {
    @slon_api_v2_search_get(session);
    return;
}
