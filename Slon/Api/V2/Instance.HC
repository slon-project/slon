U0 @slon_api_v2_instance_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "{\"domain\":\"%s\"}", db->o("instance")->@("uri"));
    @slon_http_set_content_type(session, "application/json; charset=utf-8");
    @slon_http_send_string(session, scratch_buffer);
}
