if (!StrICmp("/.well-known/host-meta", @slon_http_request_path(session))) {
    @slon_host_meta(session);
    return;
}

if (!StrICmp("/.well-known/nodeinfo", @slon_http_request_path(session))) {
    @slon_nodeinfo(session);
    return;
}

if (!StrICmp("/.well-known/oauth-authorization-server", @slon_http_request_path(session))) {
    @slon_oauth_well_known(session);
    return;
}

if (!StrICmp("/.well-known/webfinger", @slon_http_request_path(session))) {
    @slon_webfinger(session);
    return;
}
