if (!StrICmp("/oauth/token", @slon_http_request_path(session))) {
    @slon_oauth_token_post(session);
    return;
}
