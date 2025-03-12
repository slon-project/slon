if (!StrICmp("/api/v1/announcements", session->path())) {
    @slon_api_v1_announcements_get(session);
    return;
}
