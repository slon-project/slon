if (!StrICmp("/api/v1/instance", @slon_http_request_path(session))) {
    @slon_http_send_json(session, db->o("instance"));
    return;
}

if (!StrICmp("/api/v2/instance", @slon_http_request_path(session))) {
    @slon_api_v2_instance_get(session);
    return;
}
