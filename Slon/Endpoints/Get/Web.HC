if (String.EndsWith(".css", session->path())) {
    session->content_type("text/css");
    @slon_http_send_file(session, "M:/Slon/Static/css/main.css");
    return;
}

if (!StrICmp("/js/header.js", session->path())) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/header.js");
    return;
}

if (String.EndsWith(".js", session->path())) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/statuses.js");
    return;
}

if (!StrICmp("/alec.png", session->path())) {
    session->content_type("image/png");
    @slon_http_send_file(session, "A:/avatar-circle-4bpp.png");
    return;
}

if (String.BeginsWith("/@", session->path())) {
    @slon_web_user_get(session);
    return;
}
