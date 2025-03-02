if (String.BeginsWith("/api/v1/media", session->path())) {
    @slon_api_v1_media_put(session);
    return;
}
