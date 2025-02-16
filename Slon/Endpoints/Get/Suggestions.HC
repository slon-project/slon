if (!StrICmp("/api/v2/suggestions", @slon_http_request_path(session))) {
    @slon_api_v2_suggestions_get(session);
    return;
}
