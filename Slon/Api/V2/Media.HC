U0 @slon_api_v2_media_post(SlonHttpSession* session)
{
    // NOTE: We only support images at the moment

    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {

        if (!request_json->@("file")) {
            session->status(400);
            return;
        }

        SlonMultipartFile* file = request_json->@("file");
        if (!file->buffer || !file->size || !file->content_type) {
            session->status(400);
            return;
        }

        U8* media_id = @slon_api_generate_unique_id(session);
        U8* media_file_ext = StrFind("/", file->content_type) + 1;

        I32 width = 0;
        I32 height = 0;
        I32 comp = 0;
        I32 code = @stbi_info_from_memory(file->buffer, file->size, &width, &height, &comp);

        // Buffer contains a valid image file
        if (code != 1) {
            session->status(400);
            return;
        }

        // Write image file to RAM disk
        StrPrint(scratch_buffer, "%s/%s.%s", SLON_MEDIA_PATH, media_id, media_file_ext);
        FileWrite(scratch_buffer, file->buffer, file->size);

        // Create media object
        JsonObject* media_object = Json.CreateObject();
        media_object->set("id", media_id, JSON_STRING);
        media_object->set("type", "image", JSON_STRING);
        media_object->set("url", NULL, JSON_NULL);
        media_object->set("preview_url", NULL, JSON_NULL);
        media_object->set("remote_url", NULL, JSON_NULL);
        media_object->set("meta", Json.CreateObject(), JSON_OBJECT);
        media_object->o("meta")->set("original", Json.CreateObject(), JSON_OBJECT);
        media_object->o("meta")->o("original")->set("width", width, JSON_NUMBER);
        media_object->o("meta")->o("original")->set("height", height, JSON_NUMBER);
        media_object->set("description", NULL, JSON_NULL);
        media_object->set("blurhash", NULL, JSON_NULL);
        db->o("media")->set(media_id, media_object, JSON_OBJECT);

        // Then, async upload the image file to Catbox
        SlonCatboxUpload* cb = CAlloc(sizeof(SlonCatboxUpload), adam_task);
        cb->key = media_object->@("url", TRUE);
        cb->filepath = StrNew(scratch_buffer, adam_task);
        Spawn(&@slon_api_async_upload_to_catbox, cb, "SlonAsyncCatboxUpload");

        session->send(media_object);
        session->status(202);

        @slon_free(session, media_id);
    } else {
        session->status(401);
    }
}
