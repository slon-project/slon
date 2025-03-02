U8* @slon_api_v2_media_upload_to_catbox(SlonHttpSession* session, U8* filepath)
{
    if (!session || !filepath) {
        return NULL;
    }

    I64 data_size = 0;
    U8* data = FileRead(filepath, &data_size);
    U8* image_url = NULL;

    // build the multipart/form-data payload

    U8* payload = @slon_calloc(session, 4096 + data_size);
    I64 payload_size = 0;

    U8* boundary = "----------SlonFormBoundary00";
    StrPrint(payload, "--%s\r\n", boundary);

    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "reqtype", "fileupload", boundary);
    if (db->o("settings")->@("catbox_userhash")) {
        String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "userhash", db->o("settings")->@("catbox_userhash"), boundary);
    }
    U8* random_filename = @slon_api_generate_unique_id(session);
    U8* ext = StrFind(".", filepath) + 1;
    String.Append(payload, "Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"%s.%s\"\r\n", random_filename, ext);
    String.Append(payload, "Content-Type: image/%s\r\n\r\n", ext);
    payload_size = StrLen(payload);
    @slon_free(session, random_filename);

    MemCpy(payload + payload_size, data, data_size);
    payload_size += data_size;
    StrPrint(payload + payload_size, "\r\n--%s--\r\n", boundary);
    payload_size += 8;
    payload_size += StrLen(boundary);

    // build the http headers
    U8* headers = @slon_calloc(session, 4096);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = @slon_calloc(session, send_buffer_size);

    MemCpy(send_buffer, headers, StrLen(headers));
    MemCpy(send_buffer + StrLen(headers), payload, payload_size);

    TlsSocket* s = @tls_socket_create("catbox.moe", 443);
    while (!@tls_established(s->ctx))
        Sleep(1);

    I64 left = send_buffer_size;
    I64 sent = 0;
    I64 chunk_size = 0;
    while (left) {
        chunk_size = 2048;
        if (chunk_size > left)
            chunk_size = left;
        s->send(send_buffer + sent, chunk_size);
        left -= chunk_size;
        sent += chunk_size;
        Sleep(10);
    }

    I64 bytes_received = 0;
    I64 response_buffer_size = 0;
    U8* response_buffer = @slon_calloc(session, 4096);

    while (!bytes_received) {
        bytes_received = s->receive(response_buffer + response_buffer_size, 4096);
        response_buffer_size += bytes_received;
    }

    s->close();

    U8* url_ptr = StrFind("\r\n\r\n", response_buffer) + 4;
    if (url_ptr < 0x10) {
        goto slon_api_v2_media_upload_to_catbox_failed;
    }
    url_ptr = StrFind("\r\n", url_ptr) + 2;
    StrFind("\r\n", url_ptr)[0] = NULL;

    image_url = @slon_strnew(session, url_ptr);

slon_api_v2_media_upload_to_catbox_failed:

    @slon_free(session, response_buffer);
    @slon_free(session, send_buffer);
    @slon_free(session, headers);
    @slon_free(session, payload);
    Free(data);

    return image_url;
}

U0 @slon_api_v2_media_post(SlonHttpSession* session)
{
    // NOTE: We only support images at the moment

    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    if (@slon_api_authorized(session)) {
        U8* data = session->request->data;

        // Advance to Content-Disposition for file attachment
        data = StrFind("filename=", data);

        if (!data) {
            session->status(400);
            return;
        }

        if (!StrFind("\r\n\r\n", data)) {
            session->status(400);
            return;
        }

        // Mark beginning of file data
        U8* file_ptr = StrFind("\r\n\r\n", data) + 4;

        // NULL terminate Content-Type
        StrFind("\r\n\r\n", data)[0] = NULL;

        U8* mime_type = StrFind("Content-Type: ", data);
        if (!mime_type) {
            session->status(400);
            return;
        }
        mime_type += 14; // StrLen("Content-Type: ")

        if (!String.BeginsWith("image/", mime_type)) {
            session->status(400);
            return;
        }

        U8* boundary = StrFind("boundary=", session->header("content-type")) + 9;
        I64 content_length = Str2I64(session->header("content-length"));
        // Strip begin double-quotes and ending CRLF, double-quotes
        while (boundary[0] == '"')
            boundary++;
        // Rstrip EOL
        while (boundary[StrLen(boundary) - 1] == '\"' || boundary[StrLen(boundary) - 1] == ' ' || boundary[StrLen(boundary) - 1] == '\r' || boundary[StrLen(boundary) - 1] == '\n')
            boundary[StrLen(boundary) - 1] = NULL;

        // Get file size
        StrPrint(scratch_buffer, "\r\n--%s", boundary);
        I64 file_size = 0;
        I64 scratch_buffer_len = StrLen(scratch_buffer);
        while (file_size < content_length && MemCmp(file_ptr + file_size, scratch_buffer, scratch_buffer_len)) {
            ++file_size;
        }

        // File size is non-zero and within bounds
        if (!file_size || file_size >= content_length) {
            session->status(400);
            return;
        }

        I32 width = 0;
        I32 height = 0;
        I32 comp = 0;
        I32 code = @stbi_info_from_memory(file_ptr, file_size, &width, &height, &comp);

        // Buffer contains a valid image file
        if (code != 1) {
            session->status(400);
            return;
        }

        U8* media_id = @slon_api_generate_unique_id(session);
        U8* media_file_ext = StrFind("/", mime_type) + 1;

        // Write image file to RAM disk
        StrPrint(scratch_buffer, "%s/%s.%s", SLON_MEDIA_PATH, media_id, media_file_ext);
        FileWrite(scratch_buffer, file_ptr, file_size);

        // Then, upload to Catbox
        U8* media_url = @slon_api_v2_media_upload_to_catbox(session, scratch_buffer);
        if (media_url) {
            JsonObject* media_object = Json.CreateObject();
            media_object->set("id", media_id, JSON_STRING);
            media_object->set("type", "image", JSON_STRING);
            media_object->set("url", media_url, JSON_STRING);
            media_object->set("preview_url", NULL, JSON_NULL);
            media_object->set("remote_url", NULL, JSON_NULL);
            media_object->set("meta", Json.CreateObject(), JSON_OBJECT);
            media_object->o("meta")->set("original", Json.CreateObject(), JSON_OBJECT);
            media_object->o("meta")->o("original")->set("width", width, JSON_NUMBER);
            media_object->o("meta")->o("original")->set("height", height, JSON_NUMBER);
            media_object->set("description", NULL, JSON_NULL);
            media_object->set("blurhash", NULL, JSON_NULL);
            db->o("media")->set(media_id, media_object, JSON_OBJECT);
            session->send(media_object);
            @slon_free(session, media_url);
        } else {
            session->status(400);
        }

        // Delete image from RAM disk
        Del(scratch_buffer);

        @slon_free(session, media_id);
    } else {
        session->status(401);
    }
}
