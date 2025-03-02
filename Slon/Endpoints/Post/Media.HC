if (!StrICmp("/api/v2/media", session->path())) {
    @slon_api_v2_media_post(session);
    return;
}
