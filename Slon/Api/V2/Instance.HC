U0 @slon_api_v2_instance_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "{\"domain\":\"%s\"}", db->o("instance")->@("uri"));
    session->content_type("application/json; charset=utf-8");
    session->send(scratch_buffer);
}
