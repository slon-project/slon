if (!StrICmp("/api/v1/apps", session->path())) {
    @slon_api_v1_apps_post(session);
    return;
}
