if (String.BeginsWith("/api/v1/statuses", session->path())) {
    @slon_api_v1_statuses_post(session);
    return;
}
