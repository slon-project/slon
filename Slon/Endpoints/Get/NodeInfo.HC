if (!StrICmp("/nodeinfo/2.0", @slon_http_request_path(session))) {
    @slon_nodeinfo_20(session);
    return;
}
