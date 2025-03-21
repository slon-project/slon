U0 @slon_nodeinfo(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "{\"links\":[{\"rel\":\"http://nodeinfo.diaspora.software/ns/schema/2.0\",\"href\":\"https://%s/nodeinfo/2.0\"}]}", db->o("instance")->@("uri"));
    session->content_type("application/json; charset=utf-8");
    session->send(scratch_buffer);
}

U0 @slon_nodeinfo_20(SlonHttpSession* session)
{
    JsonObject* nodeinfo = Json.CreateObject(slon_mem_task);
    nodeinfo->set("version", "2.0", JSON_STRING);
    nodeinfo->set("software", Json.CreateObject(slon_mem_task), JSON_OBJECT);
    nodeinfo->o("software")->set("name", "slon", JSON_STRING);
    nodeinfo->o("software")->set("version", db->o("instance")->@("version"), JSON_STRING);
    nodeinfo->set("protocols", Json.Parse("[\"activitypub\"]", slon_mem_task), JSON_ARRAY);
    nodeinfo->set("services", Json.Parse("{\"outbound\":[],\"inbound\":[]}", slon_mem_task), JSON_OBJECT);
    nodeinfo->set("usage", Json.CreateObject(slon_mem_task), JSON_OBJECT);
    nodeinfo->o("usage")->set("users", Json.CreateObject(slon_mem_task), JSON_OBJECT);
    nodeinfo->o("usage")->o("users")->set("total", db->o("instance")->o("stats")->@("user_count"), JSON_NUMBER);
    // FIXME: return activeMonth, activeHalfyear
    nodeinfo->o("usage")->o("users")->set("activeMonth", 0, JSON_NUMBER);
    nodeinfo->o("usage")->o("users")->set("activeHalfyear", 0, JSON_NUMBER);
    nodeinfo->set("localPosts", db->o("instance")->o("stats")->@("status_count"), JSON_NUMBER);
    nodeinfo->set("openRegistrations", db->o("instance")->@("registrations"), JSON_BOOLEAN);
    nodeinfo->set("metadata", Json.CreateObject(slon_mem_task), JSON_OBJECT);
    nodeinfo->o("metadata")->set("nodeName", db->o("instance")->@("title"), JSON_STRING);
    nodeinfo->o("metadata")->set("nodeDescription", db->o("instance")->@("description"), JSON_STRING);
    session->send(nodeinfo);
}
