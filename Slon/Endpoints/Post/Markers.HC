if (!StrICmp("/api/v1/markers", session->path())) {
    @slon_api_v1_markers_post(session);
    return;
}
