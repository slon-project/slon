if (String.BeginsWith("/api/v1/timelines", @slon_http_request_path(session))) {
    @slon_api_v1_timelines_get(session);
    return;
}
