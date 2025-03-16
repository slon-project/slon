if (String.BeginsWith("/api/v1/polls", session->path())) {
    @slon_api_v1_polls_get(session);
    return;
}
