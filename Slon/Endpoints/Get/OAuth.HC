if (!StrICmp("/oauth/authorize", @slon_http_request_path(session))) {
    @slon_http_send_html_file(session, "M:/Slon/Static/oauth/authorize.html");
    return;
}

if (!StrICmp("/oauth/verify_access", @slon_http_request_path(session))) {
    @slon_oauth_verify_access_get(session);
    return;
}
