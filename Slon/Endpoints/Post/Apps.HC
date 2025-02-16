if (!StrICmp("/api/v1/apps", @slon_http_request_path(session))) {
    @slon_api_v1_apps_post(session);
    return;
}
