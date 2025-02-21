if (String.BeginsWith("/api/v1/accounts", session->path())) {
    @slon_api_v1_accounts_get(session);
    return;
}
