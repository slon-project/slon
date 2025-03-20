if (String.BeginsWith("/api/v1/notifications", session->path())) {
    @slon_api_v1_notifications_post(session);
    return;
}
