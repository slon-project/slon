if (!StrICmp("/nodeinfo/2.0", session->path())) {
    @slon_nodeinfo_20(session);
    return;
}
