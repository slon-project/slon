U0 @slon_host_meta(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><XRD xmlns=\"http://docs.oasis-open.org/ns/xri/xrd-1.0\"><Link rel=\"lrdd\" template=\"https://%s/.well-known/webfinger?resource={uri}\"/></XRD>", db->o("instance")->@("uri"));
    @slon_http_set_content_type(session, "application/xrd+xml; charset=utf-8");
    session->send(scratch_buffer);
}
