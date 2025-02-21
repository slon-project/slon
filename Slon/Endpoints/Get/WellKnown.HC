if (!StrICmp("/.well-known/host-meta", session->path())) {
    @slon_host_meta(session);
    return;
}

if (!StrICmp("/.well-known/nodeinfo", session->path())) {
    @slon_nodeinfo(session);
    return;
}

if (!StrICmp("/.well-known/oauth-authorization-server", session->path())) {
    @slon_oauth_well_known(session);
    return;
}

if (!StrICmp("/.well-known/webfinger", session->path())) {
    @slon_webfinger(session);
    return;
}
