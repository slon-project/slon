if (!StrICmp("/api/v1/favourites", session->path())) {
    @slon_api_v1_favourites_get(session);
    return;
}
