if (!StrICmp("/oauth/authorize", session->path())) {
    @slon_http_send_html_file(session, "M:/Slon/Static/oauth/authorize.html");
    return;
}

if (!StrICmp("/oauth/verify_access", session->path())) {
    @slon_oauth_verify_access_get(session);
    return;
}
