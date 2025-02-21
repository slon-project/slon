U0 @slon_local_server_set_mime_type(SlonHttpSession* session, U8* filepath)
{
    // FIXME: Do this programmatically like the Jakt version, this is awful
    if (String.EndsWith(".html", filepath)) {
        session->content_type("text/html");
        return;
    }
    if (String.EndsWith(".txt", filepath)) {
        session->content_type("text/plain");
        return;
    }
    if (String.EndsWith(".css", filepath)) {
        session->content_type("text/css");
        return;
    }
    if (String.EndsWith(".js", filepath)) {
        session->content_type("text/javascript");
        return;
    }
    if (String.EndsWith(".json", filepath)) {
        session->content_type("application/json");
        return;
    }
    if (String.EndsWith(".gif", filepath)) {
        session->content_type("image/gif");
        return;
    }
    if (String.EndsWith(".png", filepath)) {
        session->content_type("image/png");
        return;
    }
    if (String.EndsWith(".jpeg", filepath) || String.EndsWith(".jpg", filepath)) {
        session->content_type("image/jpeg");
        return;
    }
    session->content_type("application/octet-stream");
}

U0 @slon_local_server_send_file(SlonHttpSession* session, U8* filepath)
{
    @slon_local_server_set_mime_type(session, filepath);
    @slon_http_send_file(session, filepath);
}

U0 @slon_local_server_directory_listing(SlonHttpSession* session, U8* path)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    U8* html = @slon_calloc(session, 1048576);

    String.Append(html, "<html><head><title>Index of ");
    String.Append(html, path);
    String.Append(html, "</title><style type=text/css>.img-back{content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAWCAMAAAD3n0w0AAAAElBMVEX////M//+ZmZlmZmYzMzMAAACei5rnAAAAAnRSTlP/AOW3MEoAAABVSURBVHjabdFBCsBACENR45j7X7kQtC0T//KRjRhYevGgyjBL+VLZUtlS2VItS1AI1QQONgNZHCSUZJAc+ZB3sViFGzPcDmxZqdsvgRB/aJRu73D0HuO2BJfZn2SOAAAAAElFTkSuQmCC)} .img-folder{content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAWCAMAAAD3n0w0AAAAElBMVEX/////zJnM//+ZZjMzMzMAAADCEvqoAAAAA3RSTlP//wDXyg1BAAAASElEQVR42s3KAQbAQAxE0W4m//5XboesdihQ6A/ES4566TsyPZE1caNtwmFE22bBuDTtG8ZMaoyZ8Z+fijEWytpYdEZfWGRdJzEsA9OaTRTxAAAAAElFTkSuQmCC)} .img-file{content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAWCAMAAAD3n0w0AAAAD1BMVEX////M//+ZmZkzMzMAAABVsTOVAAAAAnRSTlP/AOW3MEoAAAA6SURBVHja3cjHAcAwEIRATqj/lp3jWhUYfoPPag+5EkeII8QRYmB3O3ArENrSB0k8+ivaXrliVY+qZm7SAaxLXnOsAAAAAElFTkSuQmCC)}</style></head><body><h1>Index of ");
    String.Append(html, path);
    String.Append(html, "</h1><table>");
    String.Append(html, "<tr><th></th><th align=left style=padding-right:16px>Name</th><th align=left>Last modified</th><th align=right>Size</th></tr>");
    String.Append(html, "<tr><th colspan=4><hr></th></tr>");
    StrPrint(scratch_buffer, "A:%s*", path);
    CDirEntry* files = FilesFind(scratch_buffer);
    CDirEntry* de = files->next;
    CDateStruct ds;
    while (de) {
        String.Append(html, "<tr><td><a href=\"");
        String.Append(html, de->name);
        String.Append(html, "\">");
        if (!StrICmp("..", de->name)) {
            String.Append(html, "<img class=img-back alt=Back>");
        } else {
            if (de->attr & RS_ATTR_DIR) {
                String.Append(html, "<img class=img-folder alt=Folder>");
            } else {
                String.Append(html, "<img class=img-file alt=File>");
            }
        }
        String.Append(html, "</a></td>");
        String.Append(html, "<td><a href=\"");
        String.Append(html, de->name);
        if (de->attr & RS_ATTR_DIR) {
            String.Append(html, "/");
        }
        String.Append(html, "\">");
        if (!StrICmp("..", de->name)) {
            String.Append(html, "Parent Directory");
        } else {
            String.Append(html, de->name);
        }
        String.Append(html, "</a></td><td align=right>");
        Date2Struct(&ds, de->datetime);
        String.Append(html, "%02d-%03tZ-%04d %02d:%02d", ds.day_of_mon, ds.mon - 1, "ST_MONTHS", ds.year, ds.hour, ds.min);
        String.Append(html, "  ");
        String.Append(html, "</td><td align=right>");
        if (de->attr & RS_ATTR_DIR) {
            String.Append(html, "  - ");
        } else {
            String.Append(html, "%d", de->size);
        }

        String.Append(html, "</td></tr>");
        de = de->next;
    }
    DirTreeDel(files);

    String.Append(html, "<tr><th colspan=4><hr></th></tr>");
    String.Append(html, "</table>");
    String.Append(html, "<address>Slon static file webserver for (TempleOS) Server</address>");
    String.Append(html, "</body></html>");

    session->content_type("text/html");
    session->send(html, StrLen(html));
    @slon_free(session, html);
}

U0 @slon_local_server_not_found(SlonHttpSession* session)
{
    session->status(404);
    session->content_type("text/html");
    session->send("<h2>404 Not Found</h2>", 22);
}

U0 @slon_local_server_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    U8* path = session->path();

    if (!path || !StrLen(path) || StrFind(":", path) > 0) {
        @slon_local_server_not_found(session);
        return;
    }

    if (path[0] == '/' && StrLen(path) == 1) {
        // Handle root path
        if (FileFind("A:/index.html")) {
            @slon_local_server_send_file(session, "A:/index.html");
        } else {
            @slon_local_server_directory_listing(session, "/");
        }
        return;
    }

    if (String.EndsWith("/", path)) {
        StrPrint(scratch_buffer, "A:%sindex.html", path);
        if (FileFind(scratch_buffer)) {
            @slon_local_server_send_file(session, scratch_buffer);
        } else {
            StrPrint(scratch_buffer, "A:%s", path);
            scratch_buffer[StrLen(scratch_buffer) - 1] = NULL;
            if (IsDir(scratch_buffer)) {
                @slon_local_server_directory_listing(session, path);
            } else {
                @slon_local_server_not_found(session);
            }
        }
        return;
    }

    StrPrint(scratch_buffer, "A:%s", path);
    if (!FileFind(scratch_buffer)) {
        @slon_local_server_not_found(session);
        return;
    } else {
        if (IsDir(scratch_buffer)) {
            session->status(301);
            StrPrint(scratch_buffer, "%s/", path);
            session->header("Location", scratch_buffer);
        } else {
            @slon_local_server_send_file(session, scratch_buffer);
        }
        return;
    }

    // shouldn't get here :^)
    session->status(400);
}

U0 @slon_local_http_handle_get_request(SlonHttpSession* session)
{
    @slon_local_server_get(session);
}

U0 @slon_local_http_handle_request(SlonHttpSession* session)
{
    switch (session->verb()) {
    case SLON_HTTP_VERB_GET:
        @slon_local_http_handle_get_request(session);
        break;
    default:
        session->status(405);
    }
}

U0 @slon_local_http_task(TcpSocket* s)
{
    // Bail if we can't acquire socket for some reason
    if (!@tcp_socket_accept(s))
        return;

    // Init session
    SlonHttpSession* session = @slon_http_init_session(s);

    // Parse headers if they are available
    while (!@slon_http_request_headers_have_been_parsed(session)) {
        @slon_http_receive(session);

        // Handle malformed requests (anything less than "GET / HTTP/1.0\r\n\r\n" is probably a bad request)
        if (session->request->buffer->size < 18) {
            session->status(400);
            goto slon_local_http_task_send_response;
        }

        @slon_http_try_parse_request_headers(session);
    }

    // If we have a content-length header, consume until we receive all the data, then set request->data pointer and size
    if (StrLen(session->header("content-length"))) {
        I64 content_length = Str2I64(session->header("content-length"));
        while (session->request->buffer->data + session->request->buffer->size - session->request->data < content_length)
            @slon_http_receive(session);
    }

    @slon_local_http_handle_request(session);

slon_local_http_task_send_response:
    @slon_http_send_response(session);
    @slon_http_free_session(session);
    s->close();
}

Adam("U0 @spawn_slon_local_http_task(TcpSocket *s){Spawn(%d, s, \"SlonLocalHttpTask\");};\n", &@slon_local_http_task);
@tcp_socket_bind(8000, "@spawn_slon_local_http_task");
