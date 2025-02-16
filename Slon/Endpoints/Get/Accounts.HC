if (String.BeginsWith("/api/v1/accounts", @slon_http_request_path(session))) {
    @slon_api_v1_accounts_get(session);
    return;
}
