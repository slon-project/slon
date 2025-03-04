#define SLON_API_LOCAL_TIME_OFFSET 3550
#define SLON_AUTH_ACCOUNT_ID U8* account_id = Json.Get(session->auth, "account_id");

extern @http_response* @slon_activitypub_signed_request(U8* url_string, U8* fetch_buffer, JsonObject* request_object = NULL, I64 verb = SLON_HTTP_VERB_POST, U8* signatory = NULL);

class SlonCatboxUpload {
    JsonKey* key;
    U8* filepath;
};

Bool @slon_api_authorized(SlonHttpSession* session)
{
    return session->auth > 0;
}

U8* @slon_api_generate_random_hex_string(SlonHttpSession* session, I64 size)
{
    U8* str = @slon_calloc(session, (size + 1) * 2);
    I64 i;
    for (i = 0; i < size; i++) {
        String.Append(str, "%02x", RandU64 & 0xff);
    }
    return str;
}

U8* @slon_api_generate_unique_id(SlonHttpSession* session)
{
    U8* unique_id = @slon_calloc(session, 64);
    U64 id = ((CDate2Unix(Now) + SLON_API_LOCAL_TIME_OFFSET) * 1000) << 16;
    id += RandU64 & 0xffff;
    StrPrint(unique_id, "%d", id);
    return unique_id;
}

U8* @slon_api_timestamp_from_cdate(SlonHttpSession* session, CDate* date)
{
    CDateStruct ds;
    Date2Struct(&ds, date);
    U8* timestamp = @slon_calloc(session, 32);
    StrPrint(timestamp, "%04d-%02d-%02dT%02d:%02d:%02d.000-05:00", ds.year, ds.mon, ds.day_of_mon, ds.hour, ds.min, ds.sec);
    return timestamp;
}

Bool @slon_api_boolean_from_string(U8* s)
{
    // https://docs.joinmastodon.org/client/intro/#boolean
    // True-or-false (Booleans)
    // A boolean value is considered false for the values 0, f, F, false, FALSE, off, OFF; considered to not be provided for empty strings;
    // and considered to be true for all other values. When using JSON data, use the literals true, false, and null instead.
    return !(!StrICmp("0", s) || !StrICmp("f", s) || !StrICmp("false", s) || !StrICmp("off", s));
}

JsonObject* @slon_api_account_by_email(U8* email)
{
    if (!email || !StrLen(email))
        return NULL;
    JsonArray* accts = db->a("accounts");
    I64 i;
    for (i = 0; i < accts->length; i++) {
        if (!StrICmp(accts->o(i)->@("email"), email)) {
            return accts->o(i);
        }
    }
    return NULL;
}

JsonObject* @slon_api_account_by_acct(U8* acct)
{
    if (!acct || !StrLen(acct))
        return NULL;
    JsonArray* accts = db->a("accounts");
    I64 i;
    for (i = 0; i < accts->length; i++) {
        if (!StrICmp(accts->o(i)->@("acct"), acct)) {
            return accts->o(i);
        }
    }
    return NULL;
}

JsonObject* @slon_api_account_by_id(U8* id)
{
    if (!id || !StrLen(id))
        return NULL;
    JsonArray* accts = db->a("accounts");
    I64 i;
    for (i = 0; i < accts->length; i++) {
        if (!StrICmp(accts->o(i)->@("id"), id)) {
            return accts->o(i);
        }
    }
    return NULL;
}

JsonObject* @slon_api_account_by_username(U8* username)
{
    if (!username || !StrLen(username))
        return NULL;
    JsonArray* accts = db->a("accounts");
    I64 i;
    for (i = 0; i < accts->length; i++) {
        if (!StrICmp(accts->o(i)->@("username"), username)) {
            return accts->o(i);
        }
    }
    return NULL;
}

JsonObject* @slon_api_account_by_remote_actor(U8* remote_actor)
{
    if (!remote_actor || !StrLen(remote_actor))
        return NULL;
    JsonArray* accts = db->a("accounts");
    I64 i;
    for (i = 0; i < accts->length; i++) {
        if (accts->o(i)->@("remote_actor") && !StrICmp(accts->o(i)->@("remote_actor"), remote_actor)) {
            return accts->o(i);
        }
    }
    return NULL;
}

U0 @slon_api_async_upload_to_catbox(SlonCatboxUpload* cb)
{
    if (!cb) {
        return;
    }
    if (!cb->key || !cb->filepath || !FileFind(cb->filepath)) {
        Free(cb);
        return;
    }

    U8* filepath = cb->filepath;

    I64 data_size = 0;
    U8* data = FileRead(filepath, &data_size);

    // build the multipart/form-data payload

    U8* payload = CAlloc(4096 + data_size, adam_task);
    I64 payload_size = 0;

    U8* boundary = "----------SlonFormBoundary00";
    StrPrint(payload, "--%s\r\n", boundary);

    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "reqtype", "fileupload", boundary);
    if (db->o("settings")->@("catbox_userhash")) {
        String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "userhash", db->o("settings")->@("catbox_userhash"), boundary);
    }

    U8 random_filename[64];
    U64 id = ((CDate2Unix(Now) + SLON_API_LOCAL_TIME_OFFSET) * 1000) << 16;
    id += RandU64 & 0xffff;
    StrPrint(random_filename, "%d", id);

    U8* ext = StrFind(".", filepath) + 1;
    String.Append(payload, "Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"%s.%s\"\r\n", random_filename, ext);
    String.Append(payload, "Content-Type: image/%s\r\n\r\n", ext);
    payload_size = StrLen(payload);

    MemCpy(payload + payload_size, data, data_size);
    payload_size += data_size;
    StrPrint(payload + payload_size, "\r\n--%s--\r\n", boundary);
    payload_size += 8;
    payload_size += StrLen(boundary);

    // build the http headers
    U8* headers = CAlloc(4096, adam_task);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = CAlloc(send_buffer_size, adam_task);

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
    U8* response_buffer = CAlloc(4096, adam_task);

    while (!bytes_received) {
        bytes_received = s->receive(response_buffer + response_buffer_size, 4096);
        response_buffer_size += bytes_received;
    }

    s->close();

    U8* url_ptr = StrFind("\r\n\r\n", response_buffer) + 4;
    if (url_ptr < 0x10) {
        goto slon_api_upload_to_catbox_failed;
    }
    url_ptr = StrFind("\r\n", url_ptr) + 2;
    StrFind("\r\n", url_ptr)[0] = NULL;

    cb->key->value = StrNew(url_ptr, adam_task);
    cb->key->type = JSON_STRING;

slon_api_upload_to_catbox_failed:

    Free(response_buffer);
    Free(send_buffer);
    Free(headers);
    Free(payload);
    Free(data);
    Del(cb->filepath);
    Free(cb->filepath);
    Free(cb);
}

U0 @slon_api_async_delete_from_catbox(U8* filename)
{
    if (!filename) {
        return;
    }

    // build the multipart/form-data payload

    U8* payload = CAlloc(4096, adam_task);
    I64 payload_size = 0;

    U8* boundary = "----------SlonFormBoundary00";
    StrPrint(payload, "--%s\r\n", boundary);

    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "reqtype", "deletefiles", boundary);
    if (db->o("settings")->@("catbox_userhash")) {
        String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "userhash", db->o("settings")->@("catbox_userhash"), boundary);
    }
    String.Append(payload, "Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n--%s\r\n", "files", filename, boundary);
    payload_size = StrLen(payload);

    // build the http headers
    U8* headers = CAlloc(4096, adam_task);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = CAlloc(send_buffer_size, adam_task);

    MemCpy(send_buffer, headers, StrLen(headers));
    MemCpy(send_buffer + StrLen(headers), payload, payload_size);

    TlsSocket* s = @tls_socket_create("catbox.moe", 443);
    while (!@tls_established(s->ctx))
        Sleep(1);

    s->send(send_buffer, send_buffer_size);

    I64 bytes_received = 0;
    I64 response_buffer_size = 0;
    U8* response_buffer = CAlloc(4096, adam_task);

    while (!bytes_received) {
        bytes_received = s->receive(response_buffer + response_buffer_size, 4096);
        response_buffer_size += bytes_received;
    }

    s->close();

    Free(response_buffer);
    Free(send_buffer);
    Free(payload);
    Free(headers);
    Free(filename);
}
