if (!StrICmp("/oauth/token", session->path())) {
    @slon_oauth_token_post(session);
    return;
}
