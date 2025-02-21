if (String.EndsWith(".css", @slon_http_request_path(session))) {
    session->content_type("text/css");
    @slon_http_send_file(session, "M:/Slon/Static/css/main.css");
    return;
}

if (!StrICmp("/js/header.js", @slon_http_request_path(session))) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/header.js");
    return;
}

if (String.EndsWith(".js", @slon_http_request_path(session))) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/statuses.js");
    return;
}

if (!StrICmp("/alec.png", @slon_http_request_path(session))) {
    session->content_type("image/png");
    @slon_http_send_file(session, "A:/avatar-circle-4bpp.png");
    return;
}

if (String.BeginsWith("/@", @slon_http_request_path(session))) {
    @slon_web_user_get(session);
    return;
}
