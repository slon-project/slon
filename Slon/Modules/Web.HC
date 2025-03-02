U0 @slon_web_user_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer, request_json;

    I64 path_segments_count = 0;
    U8** path_segments = String.Split(StrFind("@", session->path()) + 1, '/', &path_segments_count);

    U8* user = path_segments[0];
    JsonObject* actor = db->o("actors")->@(user);
    if (!actor) {
        session->status(404);
        goto slon_web_user_get_return;
    }

    I64 html_file_size;
    U8* html_file_data = FileRead("M:/Slon/Static/html/user.html", &html_file_size);
    U8* user_file_data = Json.Stringify(actor);

    U8* html_data = @slon_calloc(session, (html_file_size * 2) + (StrLen(user_file_data) * 2));
    String.Append(html_data, html_file_data);

    switch (path_segments_count) {
    case 1:
        String.Append(html_data, "<script>getStatuses(");
        break;
    default:
        String.Append(html_data, "<script>getStatusById(\"%s\",", path_segments[1]);
        break;
    }

    String.Append(html_data, user_file_data);
    String.Append(html_data, ");</script>");
    session->content_type("text/html");
    session->send(html_data, StrLen(html_data));

    Free(html_file_data);
    Free(user_file_data);
    @slon_free(session, html_data);

slon_web_user_get_return:
    Free(path_segments);
}
