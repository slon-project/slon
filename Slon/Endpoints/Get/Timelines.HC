if (String.BeginsWith("/api/v1/timelines", session->path())) {
    @slon_api_v1_timelines_get(session);
    return;
}
