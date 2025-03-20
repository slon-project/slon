if (String.BeginsWith("/api/v1/notifications", session->path())) {
    @slon_api_v1_notifications_get(session);
    return;
}

if (String.BeginsWith("/api/v2/notifications", session->path())) {
    @slon_api_v2_notifications_get(session);
    return;
}
