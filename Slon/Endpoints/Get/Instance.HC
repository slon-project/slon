if (!StrICmp("/api/v1/instance", session->path())) {
    session->send(db->o("instance"));
    return;
}

if (!StrICmp("/api/v2/instance", session->path())) {
    @slon_api_v2_instance_get(session);
    return;
}
