U0 @slon_webfinger(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    U8* resource = request_json->@("resource");
    StrPrint(scratch_buffer, "@%s", db->o("instance")->@("uri"));
    if (resource && String.BeginsWith("acct:", resource) && String.EndsWith(scratch_buffer, resource)) {
        resource = StrFind(":", resource) + 1;
        StrFind("@", resource)[0] = NULL;
        if (db->o("actors")->@(resource)) {
            JsonObject* webfinger_object = Json.CreateObject(slon_mem_task);

            StrPrint(scratch_buffer, "acct:%s@%s", resource, db->o("instance")->@("uri"));
            webfinger_object->set("subject", scratch_buffer, JSON_STRING);

            JsonArray* aliases = Json.CreateArray(slon_mem_task);
            StrPrint(scratch_buffer, "https://%s/@%s", db->o("instance")->@("uri"), resource);
            aliases->append(scratch_buffer, JSON_STRING);
            StrPrint(scratch_buffer, "https://%s/users/%s", db->o("instance")->@("uri"), resource);
            aliases->append(scratch_buffer, JSON_STRING);
            webfinger_object->set("aliases", aliases, JSON_ARRAY);

            JsonArray* links = Json.CreateArray(slon_mem_task);
            JsonObject* link_object = Json.CreateObject(slon_mem_task);
            link_object->set("rel", "self", JSON_STRING);
            link_object->set("type", "application/activity+json", JSON_STRING);
            StrPrint(scratch_buffer, "https://%s/users/%s", db->o("instance")->@("uri"), resource);
            link_object->set("href", scratch_buffer, JSON_STRING);
            links->append(link_object);
            webfinger_object->set("links", links, JSON_ARRAY);

            session->send(webfinger_object);
        } else {
            session->status(404);
        }
    } else {
        session->status(400);
    }
}
