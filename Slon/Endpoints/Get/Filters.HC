if (!StrICmp("/api/v1/filters", session->path())) {
    @slon_api_v1_filters_get(session);
    return;
}

if (!StrICmp("/api/v2/filters", session->path())) {
    @slon_api_v2_filters_get(session);
    return;
}
