if (String.EndsWith(".css", session->path())) {
    session->content_type("text/css");
    @slon_http_send_file(session, "M:/Slon/Static/css/main.css");
    return;
}

if (!StrICmp("/json/about.json", session->path())) {
    JsonArray* about = Json.CreateArray(session->mem_task);
    about->append(Json.CreateObject(session->mem_task), JSON_OBJECT);
    about->o(0)->set("url", "_About this instance", JSON_STRING);
    about->o(0)->set("content", db->o("settings")->@("about_page_content"), JSON_STRING);
    session->send(about);
    return;
}

if (!StrICmp("/js/header.js", session->path())) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/header.js");
    return;
}

if (!StrICmp("/js/statuses.js", session->path())) {
    session->content_type("text/javascript");
    @slon_http_send_file(session, "M:/Slon/Static/js/statuses.js");
    return;
}

if (String.BeginsWith("/@", session->path())) {
    @slon_web_user_get(session);
    return;
}

if (!StrICmp("/about", session->path())) {
    @slon_http_send_html_file(session, "M:/Slon/Static/html/about.html");
    return;
}

if (!StrICmp("/", session->path()) || !StrICmp("/index.html", session->path())) {
    session->header("Location", "/about");
    session->status(302);
    return;
}

//    <script>);
