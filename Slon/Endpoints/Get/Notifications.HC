if (String.BeginsWith("/api/v1/notifications", @slon_http_request_path(session))) {
    @slon_api_v1_notifications_get(session);
    return;
}
