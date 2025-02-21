if (!StrICmp("/api/v2/suggestions", session->path())) {
    @slon_api_v2_suggestions_get(session);
    return;
}
