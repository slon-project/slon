SlonHttpSession* SLON_AP_DUMMY_SESSION = CAlloc(sizeof(SlonHttpSession));
SLON_AP_DUMMY_SESSION->mem_task = slon_mem_task;

Bool @slon_activitypub_status_exists(JsonArray* statuses, U8* uri)
{
    if (!statuses || !uri) {
        return FALSE;
    }
    JsonObject* status = NULL;
    I64 i;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!StrICmp(uri, status->@("uri"))) {
            return TRUE;
        }
    }
    return FALSE;
}

U8* @slon_activitypub_strip_double_quotes(U8* str)
{
    while (str[0] == '"')
        str++;
    while (str[StrLen(str) - 1] == '"')
        str[StrLen(str) - 1] = NULL;
    return str;
}

Bool @slon_activitypub_http_signature_is_valid(SlonHttpSession* session, U8* user)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (db->o("settings")->@("http_signature_is_always_valid")) {
        goto http_signature_skip_digest_check;
    }

    // 1. Check that we have a signature and digest
    if (!StrLen(session->header("signature")) || !StrLen(session->header("digest"))) {
        AdamLog("[verify_signature] no signature or digest header present\n");
        return FALSE;
    }

    // 2. Check that digest 1) is SHA-256 and 2) matches content
    U8* request_digest = session->header("digest");
    if (!(String.BeginsWith("SHA-256", request_digest) || String.BeginsWith("sha-256", request_digest))) {
        AdamLog("[verify_signature] digest is not SHA-256\n");
        return FALSE;
    }
    request_digest = StrFind("=", request_digest) + 1;
    I64 content_length = Str2I64(session->header("content-length"));
    if (!content_length) {
        AdamLog("[verify_signature] content-length is 0\n");
        return FALSE;
    }

    U8 content_hash[512];
    calc_sha_256(content_hash, session->request->data, content_length);
    U8* computed_digest = @base64_encode(content_hash, 32);

    if (StrICmp(computed_digest, request_digest)) {
        AdamLog("[verify_signature] digest header and computed digest do not match\n");
        Free(computed_digest);
        return FALSE;
    } else {
        Free(computed_digest);
    }

http_signature_skip_digest_check:
    // Parse values from Signature header
    U8* signature_header = session->header("signature");
    I64 signature_fragment_count = 0;
    U8** signature_fragments = String.Split(signature_header, ',', &signature_fragment_count);

    U8* keyId = NULL;
    U8* algorithm = NULL;
    U8* headers = NULL;
    U8* signature = NULL;

    I64 i;
    for (i = 0; i < signature_fragment_count; i++) {
        if (String.BeginsWith("keyId=", signature_fragments[i])) {
            keyId = signature_fragments[i] + 6;
            keyId = @slon_activitypub_strip_double_quotes(keyId);
        }
        if (String.BeginsWith("algorithm=", signature_fragments[i])) {
            algorithm = signature_fragments[i] + 10;
            algorithm = @slon_activitypub_strip_double_quotes(algorithm);
        }
        if (String.BeginsWith("headers=", signature_fragments[i])) {
            headers = signature_fragments[i] + 8;
            headers = @slon_activitypub_strip_double_quotes(headers);
        }
        if (String.BeginsWith("signature=", signature_fragments[i])) {
            signature = signature_fragments[i] + 10;
            signature = @slon_activitypub_strip_double_quotes(signature);
        }
    }

    // 3. Confirm actor and keyId are present
    if (!request_json->@("actor")) {
        AdamLog("[verify_signature] actor is not present in request\n");
        return FALSE;
    }
    if (!keyId) {
        AdamLog("[verify_signature] keyId is not present in signature\n");
        return FALSE;
    }
    session->actor_for_key_id = @slon_strnew(session, keyId);
    StrFind("#", session->actor_for_key_id)[0] = NULL;

    if (db->o("settings")->@("http_signature_is_always_valid")) {
        return TRUE;
    }

    // Check if public key is cached for keyId, if not, fetch it
    if (!db->o("public_keys")->@(keyId)) {

        @slon_log(LOG_HTTPD, "Signatory's public key is not cached, attempting to fetch");

        U8* signatory_url_string = @slon_strnew(session, keyId);
        StrFind("#", signatory_url_string)[0] = NULL;

        U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
        U8* signatory = db->o("actors")->o(user)->@("id");
        @http_response* resp = @slon_activitypub_signed_request(signatory_url_string, fetch_buffer, NULL, SLON_HTTP_VERB_GET, signatory);
        @slon_free(session, signatory_url_string);

        if (!resp) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, invalid response from remote server");
            Free(fetch_buffer);
            return FALSE;
        }

        if (!resp->body.length) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, empty response from remote server");
            Free(fetch_buffer);
            return FALSE;
        }

        JsonObject* user_object = Json.Parse(resp->body.data, slon_mem_task);
        Free(fetch_buffer);

        if (!user_object) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, user object not present in response from remote server");
            return FALSE;
        }

        JsonObject* pubkey_object = user_object->@("publicKey");
        if (!pubkey_object) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, publicKey object not present in user object");
            return FALSE;
        }

        if (!pubkey_object->@("id")) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, id not present in publicKey object");
            return FALSE;
        }
        if (!pubkey_object->@("owner")) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, owner not present in publicKey object");
            return FALSE;
        }
        if (!pubkey_object->@("publicKeyPem")) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, publicKeyPem not present in publicKey object");
            return FALSE;
        }

        if (StrICmp(pubkey_object->@("id"), keyId)) {
            @slon_log(LOG_HTTPD, "Could not fetch signatory's public key, keyId does not match id present in publicKey object");
            return FALSE;
        }

        U8* pem_string = pubkey_object->@("publicKeyPem");

        // Convert Base64 PEM to single line
        U8* pem_single_line = @slon_calloc(session, StrLen(pem_string));
        I64 pem_lines_count = 0;
        U8** pem_lines = String.Split(pem_string, '\n', &pem_lines_count);
        i = 0;
        while (i < pem_lines_count) {
            if (pem_lines[i] && StrLen(pem_lines[i]) > 0) {
                if (!StrFind("KEY", pem_lines[i])) {
                    StrCpy(pem_single_line + StrLen(pem_single_line), pem_lines[i]);
                }
            }
            ++i;
        }

        // Decode PEM to DER
        I64 der_buf_length = 0;
        U8* der_buf = @base64_decode(pem_single_line, &der_buf_length);

        // Cache the public key
        JsonObject* cached_key = Json.CreateObject(slon_mem_task);
        cached_key->set("key", der_buf, JSON_NUMBER);
        cached_key->set("length", der_buf_length, JSON_NUMBER);
        db->o("public_keys")->set(keyId, cached_key, JSON_OBJECT);

        @slon_free(session, pem_single_line);
    }

    // Calculate our signature string allocation
    I64 sig_string_alloc_length = 0;

    I64 headers_split_count = 0;
    U8** headers_split = String.Split(headers, ' ', &headers_split_count);
    i = 0;
    while (i < headers_split_count) {
        sig_string_alloc_length += StrLen(session->header(headers_split[i]));
        ++i;
    }
    sig_string_alloc_length += StrLen(session->verb(1));
    sig_string_alloc_length += StrLen(session->path());
    sig_string_alloc_length *= 2;

    // Construct our signature string
    U8* sig_string = @slon_calloc(session, sig_string_alloc_length);
    i = 0;
    while (i < headers_split_count) {
        if (StrLen(headers_split[i]) && headers_split[i][0] >= 'A' && headers_split[i][0] <= 'Z') {
            headers_split[i][0] += 'a' - headers_split[i][0];
        }
        if (!StrCmp("(request-target)", headers_split[i])) {
            String.Append(sig_string, "(request-target): %s %s", "post", session->path());
        } else {
            String.Append(sig_string, "%s: %s", headers_split[i], session->header(headers_split[i]));
        }
        ++i;
        if (i < headers_split_count) {
            String.Append(sig_string, "\n");
        }
    }

    // Base64 decode request's signature
    I64 verify_sig_buf_length = 0;
    U8* verify_sig_buf = @base64_decode(signature, &verify_sig_buf_length);

    // Hash our constructed signature string
    U8 sig_string_hash[32];
    calc_sha_256(sig_string_hash, sig_string, StrLen(sig_string));

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, slon_mem_task);
    I64 res = @rsa_import(db->o("public_keys")->o(keyId)->@("key"), db->o("public_keys")->o(keyId)->@("length"), rsa_key);
    if (res != 0) { // CRYPT_OK = 0
        @slon_log(LOG_HTTPD, "Received error from @rsa_import: %d", res);
        return FALSE;
    }

    // Verify signature
    I32 stat = 0;
    res = @rsa_verify_signature(verify_sig_buf, verify_sig_buf_length, sig_string_hash, 32, &stat, rsa_key);
    if (res != 0) { // CRYPT_OK = 0
        @slon_log(LOG_HTTPD, "Received error from @rsa_verify_signature: %d", res);
        return FALSE;
    }

    Free(rsa_key);
    Free(verify_sig_buf);
    @slon_free(session, sig_string);

    return stat;
}

U0 @slon_activitypub_users_get(SlonHttpSession* session)
{
    if (session->path_count() == 3) {
        JsonObject* actor = db->o("actors")->@(session->path(1));
        if (actor) {
            @slon_http_send_ap_json(session, actor);
        } else {
            session->status(404);
        }
    } else {
        session->status(400);
    }
}

@http_response* @slon_activitypub_signed_request(U8* url_string, U8* fetch_buffer, JsonObject* request_object = NULL, I64 verb = SLON_HTTP_VERB_POST, U8* signatory = NULL)
{
    switch (verb) {
    case SLON_HTTP_VERB_GET:
        break;
    case SLON_HTTP_VERB_POST:
        break;
    default:
        @slon_log(LOG_HTTPD, "Could not send ActivityPub request, unsupported HTTP verb");
        return NULL;
    }

    if (!url_string || !fetch_buffer) {
        return NULL;
    }
    HttpUrl* url = @http_parse_url(url_string);
    if (!url) {
        return NULL;
    }

    JsonObject* http_headers = Json.CreateObject(slon_mem_task);

    U8 scratch_buffer[2048];
    U8* request_object_s = NULL;

    if (request_object) {
        signatory = request_object->@("actor");
        request_object_s = Json.Stringify(request_object, slon_mem_task);
        U8 content_hash[32];
        calc_sha_256(content_hash, request_object_s, StrLen(request_object_s));
        U8* computed_digest = @base64_encode(content_hash, 32);
        StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
        http_headers->set("Digest", scratch_buffer, JSON_STRING);
        http_headers->set("Content-Type", "application/activity+json", JSON_STRING);
        Free(computed_digest);
    }

    http_headers->set("Accept", "application/activity+json", JSON_STRING);

    CDateStruct ds;
    Date2Struct(&ds, Now + 835128000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): ");
    switch (verb) {
    case SLON_HTTP_VERB_GET:
        String.Append(scratch_buffer, "get ");
        break;
    case SLON_HTTP_VERB_POST:
        String.Append(scratch_buffer, "post ");
        break;
    default:
        break;
    }
    String.Append(scratch_buffer, "%s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s", http_headers->@("Date"));
    if (request_object) {
        String.Append(scratch_buffer, "\ndigest: %s\n", http_headers->@("Digest"));
        String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));
    }

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);
    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", signatory) + 7;

    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject(slon_mem_task);
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, slon_mem_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", signatory);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date");
    if (request_object) {
        String.Append(scratch_buffer, " digest content-type");
    }
    String.Append(scratch_buffer, "\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);
    Free(computed_sig);

    @http_response* resp = NULL;

    switch (verb) {
    case SLON_HTTP_VERB_GET:
        resp = Http.Get(url, fetch_buffer, NULL, http_headers);
        break;
    case SLON_HTTP_VERB_POST:
        resp = Http.Post(url, fetch_buffer, request_object_s, http_headers);
        break;
    default:
        break;
    }

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not send ActivityPub request, invalid response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    if (request_object_s) {
        Free(request_object_s);
    }

    resp->body.data[resp->body.length] = NULL;

    AdamLog("code: %d\n", resp->status.code);
    AdamLog(resp->body.data);

    return resp;
    // FIXME: Free url
}

U0 @slon_activitypub_async_accept_request(JsonObject* o)
{
    JsonObject* request = o->o("request");
    if (!StrICmp("accept", request->@("type")) || !StrICmp("reject", request->@("type"))) {
        return;
    }
    Sleep(1000);

    U8 scratch_buffer[1024];

    U8* this_actor = db->o("actors")->o(o->@("user"))->@("id");

    StrPrint(scratch_buffer, "%s/accept/%d", this_actor, Now);
    JsonObject* accept_object = Json.CreateObject(slon_mem_task);
    accept_object->set("@context", request->@("@context"), JSON_STRING);
    accept_object->set("id", scratch_buffer, JSON_STRING);
    accept_object->set("type", "Accept", JSON_STRING);
    accept_object->set("actor", this_actor, JSON_STRING);
    accept_object->set("object", request, JSON_OBJECT);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    StrPrint(scratch_buffer, "%s/inbox", o->@("actor_for_key_id"));
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, accept_object);
    Free(fetch_buffer);
}

U0 @slon_activitypub_async_create_status_to(JsonObject* status, U8* dest)
{
    Sleep(1000);
    I64 i;

    U8 scratch_buffer[2048];

    U8* this_actor = StrNew(status->@("uri"), slon_mem_task);
    StrFind("/statuses/", this_actor)[0] = NULL;

    JsonObject* create_object = Json.CreateObject(slon_mem_task);
    JsonObject* reply_to_status = NULL;

    create_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    StrPrint(scratch_buffer, "%s/activity", status->@("uri"));
    create_object->set("id", scratch_buffer, JSON_STRING);
    create_object->set("type", "Create", JSON_STRING);
    create_object->set("actor", this_actor, JSON_STRING);
    create_object->set("published", status->@("created_at"), JSON_STRING);
    create_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]", slon_mem_task), JSON_ARRAY);
    JsonArray* cc = Json.CreateArray(slon_mem_task);
    StrPrint(scratch_buffer, "%s/followers", this_actor);
    cc->append(scratch_buffer, JSON_STRING);
    create_object->set("cc", cc, JSON_ARRAY);

    JsonObject* note_object = Json.CreateObject(slon_mem_task);
    note_object->set("id", status->@("uri"), JSON_STRING);
    note_object->set("type", "Note", JSON_STRING);
    note_object->set("summary", NULL, JSON_NULL);
    note_object->set("published", status->@("created_at"), JSON_STRING);
    note_object->set("attributedTo", this_actor, JSON_STRING);
    note_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]", slon_mem_task), JSON_ARRAY);
    note_object->set("cc", cc, JSON_ARRAY);
    note_object->set("sensitive", status->@("sensitive"), JSON_BOOLEAN);
    note_object->set("atomUri", status->@("uri"), JSON_STRING);
    if (status->@("in_reply_to_id")) {
        reply_to_status = @slon_api_find_status_by_id(status->@("in_reply_to_id"), status->@("in_reply_to_acct_id"));
        if (reply_to_status) {
            note_object->set("inReplyTo", reply_to_status->@("uri"), JSON_STRING);
            note_object->set("inReplyToAtomUri", reply_to_status->@("uri"), JSON_STRING);
        }
    } else {
        note_object->set("inReplyTo", NULL, JSON_NULL);
        note_object->set("inReplyToAtomUri", NULL, JSON_NULL);
    }
    note_object->set("content", status->@("content"), JSON_STRING);
    JsonObject* content_map = Json.CreateObject(slon_mem_task);
    content_map->set("en", status->@("content"), JSON_STRING);
    note_object->set("contentMap", content_map, JSON_OBJECT);
    JsonArray* attachment_array = NULL;
    if (status->@("media_attachments") && status->a("media_attachments")->length) {
        attachment_array = Json.CreateArray(slon_mem_task);
        JsonArray* media_attachments = status->a("media_attachments");
        JsonObject* masto_attachment = NULL;
        JsonObject* ap_attachment = NULL;
        for (i = 0; i < media_attachments->length; i++) {
            masto_attachment = media_attachments->@(i);
            ap_attachment = Json.CreateObject(slon_mem_task);
            StrPrint(scratch_buffer, "image/%s", StrFind(".", StrFind("catbox.moe/", masto_attachment->@("url")) + 11) + 1);
            ap_attachment->set("mediaType", scratch_buffer, JSON_STRING);
            ap_attachment->set("url", masto_attachment->@("url"), JSON_STRING);
            ap_attachment->set("width", masto_attachment->o("meta")->o("original")->@("width"), JSON_NUMBER);
            ap_attachment->set("height", masto_attachment->o("meta")->o("original")->@("height"), JSON_NUMBER);
            attachment_array->append(ap_attachment, JSON_OBJECT);
        }
        note_object->set("attachment", attachment_array, JSON_ARRAY);
    } else {
        note_object->set("attachment", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    }
    note_object->set("tag", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    note_object->set("replies", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);
    note_object->set("likes", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);
    note_object->set("shares", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);

    create_object->set("object", note_object, JSON_OBJECT);
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    StrPrint(scratch_buffer, "%s/inbox", dest);
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, create_object);
    Free(fetch_buffer);
}

U0 @slon_activitypub_async_create_status(JsonObject* status)
{
    I64 i;
    JsonArray* followers = db->o("followers")->a(status->o("account")->@("username"));
    if (!followers) {
        return;
    }
    for (i = 0; i < followers->length; i++) {
        @slon_activitypub_async_create_status_to(status, followers->@(i));
    }
}

U0 @slon_activitypub_async_delete_status_to(JsonObject* status, U8* dest)
{
    Sleep(1000);
    U8 scratch_buffer[2048];

    U8* this_actor = StrNew(status->@("uri"), slon_mem_task);
    StrFind("/statuses/", this_actor)[0] = NULL;

    JsonObject* delete_object = Json.CreateObject(slon_mem_task);

    delete_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    StrPrint(scratch_buffer, "%s#delete", status->@("uri"));
    delete_object->set("id", scratch_buffer, JSON_STRING);
    delete_object->set("type", "Delete", JSON_STRING);
    delete_object->set("actor", this_actor, JSON_STRING);
    delete_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]", slon_mem_task), JSON_ARRAY);

    JsonObject* ts_object = Json.CreateObject(slon_mem_task);
    ts_object->set("id", status->@("uri"), JSON_STRING);
    ts_object->set("type", "Tombstone", JSON_STRING);
    ts_object->set("atomUri", status->@("uri"), JSON_STRING);

    delete_object->set("object", ts_object, JSON_OBJECT);
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    StrPrint(scratch_buffer, "%s/inbox", dest);
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, delete_object);
    Free(fetch_buffer);
}

U0 @slon_activitypub_async_follow(JsonObject* follow)
{
    Sleep(1000);
    U8 scratch_buffer[1024];
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    StrPrint(scratch_buffer, "%s/inbox", follow->@("object"));
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, follow);
    Free(fetch_buffer);
}

U0 @slon_activitypub_async_delete_status(JsonObject* status)
{
    I64 i;
    JsonArray* followers = db->o("followers")->a(status->o("account")->@("username"));
    if (!followers) {
        return;
    }
    for (i = 0; i < followers->length; i++) {
        @slon_activitypub_async_delete_status_to(status, followers->@(i));
    }
}

U0 @slon_activitypub_follow_fedi(JsonObject* follow)
{
    Spawn(&@slon_activitypub_async_follow, follow, "SlonAsyncFollowTask");
}

U0 @slon_activitypub_create_status_fedi(JsonObject* status)
{
    Spawn(&@slon_activitypub_async_create_status, status, "SlonAsyncCreateTask");
}

U0 @slon_activitypub_delete_status_fedi(JsonObject* status)
{
    Spawn(&@slon_activitypub_async_delete_status, status, "SlonAsyncDeleteTask");
}

@slon_api_follow_fedi = &@slon_activitypub_follow_fedi;
@slon_api_status_create_fedi = &@slon_activitypub_create_status_fedi;
@slon_api_status_delete_fedi = &@slon_activitypub_delete_status_fedi;

JsonObject* @slon_activitypub_get_account_for_remote_actor(SlonHttpSession* session, U8* remote_actor)
{
    if (!remote_actor) {
        return NULL;
    }

    JsonObject* account = @slon_api_account_by_remote_actor(remote_actor);

    if (account) {
        return account;
    }
    account = Json.CreateObject(slon_mem_task);

    HttpUrl* url = @http_parse_url(remote_actor);
    if (!url) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, malformed url or unspecified error");
        return NULL;
    }

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    JsonObject* http_headers = Json.CreateObject(slon_mem_task);
    http_headers->set("accept", "application/json", JSON_STRING);
    @http_response* resp = Http.Get(url, fetch_buffer, NULL, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, invalid response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    if (!resp->body.length) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, empty response from remote server");
        Free(fetch_buffer);
        return NULL;
    }

    JsonObject* actor_object = Json.Parse(resp->body.data, slon_mem_task);
    account = @slon_accounts_create_local_for_remote_actor(session, actor_object, remote_actor, url);
    Free(fetch_buffer);

    return account;
}

JsonObject* @slon_activitypub_status_by_uri(U8* uri, JsonArray* timeline)
{
    JsonArray* statuses = @slon_api_status_array_from_timeline(timeline);
    if (!uri || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (status->@("uri") && !StrICmp(status->@("uri"), uri)) {
            return status;
        }
    }
    return NULL;
}

JsonObject* @slon_activitypub_create_status_for_remote_account(SlonHttpSession* session, JsonObject* remote_account, JsonObject* o, JsonObject* account = NULL, U8* user = NULL)
{
    if (db->o("statuses")->a(remote_account->@("id"))) {
        if (@slon_activitypub_status_exists(db->o("statuses")->a(remote_account->@("id")), o->@("atomUri"))) {
            if (session->status) {
                // Don't set status if we're using SLON_AP_DUMMY_SESSION
                session->status(200);
            }
            return @slon_api_find_status_by_uri(o->@("atomUri"), remote_account->@("id"));
        }
    }

    I64 i;
    JsonObject* new_status = Json.CreateObject(slon_mem_task);
    U8* id = @slon_api_generate_unique_id(session);

    JsonArray* media_attachments = Json.CreateArray(slon_mem_task);
    if (o->@("attachment")) {
        JsonObject* attachment_item = NULL;
        JsonObject* media_attachment = NULL;
        JsonObject* media_meta = NULL;
        JsonArray* attachment_array = o->@("attachment");
        for (i = 0; i < attachment_array->length; i++) {
            attachment_item = attachment_array->o(i);
            if (attachment_item && attachment_item->@("mediaType") && String.BeginsWith("image", attachment_item->@("mediaType"))) {
                media_attachment = Json.CreateObject(slon_mem_task);
                media_meta = Json.CreateObject(slon_mem_task);
                media_attachment->set("id", "", JSON_STRING);
                media_attachment->set("type", "image", JSON_STRING);
                media_attachment->set("url", attachment_item->@("url"), JSON_STRING);
                media_attachment->set("preview_url", NULL, JSON_NULL);
                media_attachment->set("remote_url", NULL, JSON_NULL);
                if (attachment_item->@("width") && attachment_item->@("height")) {
                    media_meta->set("original", Json.CreateObject(slon_mem_task), JSON_OBJECT);
                    media_meta->o("original")->set("width", attachment_item->@("width"), JSON_NUMBER);
                    media_meta->o("original")->set("height", attachment_item->@("height"), JSON_NUMBER);
                }
                if (attachment_item->@("summary")) {
                    media_attachment->set("description", attachment_item->@("summary"), JSON_STRING);
                } else {
                    media_attachment->set("description", NULL, JSON_NULL);
                }
                if (attachment_item->@("blurhash")) {
                    media_attachment->set("blurhash", attachment_item->@("blurhash"), JSON_STRING);
                } else {
                    media_attachment->set("blurhash", NULL, JSON_NULL);
                }
                media_attachment->set("meta", media_meta, JSON_OBJECT);
                media_attachments->append(media_attachment);
            }
        }
    }

    if (account && (o->@("inReplyTo") || o->@("inReplyToAtomUri"))) {
        JsonObject* reply_to_post = @slon_activitypub_status_by_uri(o->@("inReplyTo"), db->o("timelines")->o("home")->a(account->@("id")));
        if (reply_to_post) {
            new_status->set("in_reply_to_id", reply_to_post->@("id"), JSON_STRING);
            new_status->set("in_reply_to_acct_id", reply_to_post->o("account")->@("id"), JSON_STRING);
        }
    }

    new_status->set("id", id, JSON_STRING);
    new_status->set("created_at", o->@("published"), JSON_STRING);
    new_status->set("content", o->@("content"), JSON_STRING);
    new_status->set("visibility", "public", JSON_STRING);
    new_status->set("uri", o->@("atomUri"), JSON_STRING);
    new_status->set("url", o->@("url"), JSON_STRING);
    new_status->set("account", remote_account, JSON_OBJECT);
    // new_status->set("application", status_app, JSON_OBJECT);
    new_status->set("reblogs_count", 0, JSON_NUMBER);
    new_status->set("favourites_count", 0, JSON_NUMBER);
    new_status->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("tags", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("mentions", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("media_attachments", media_attachments, JSON_ARRAY);
    new_status->set("replies_count", 0, JSON_NUMBER);
    new_status->set("spoiler_text", "", JSON_STRING);
    new_status->set("sensitive", o->@("sensitive"), JSON_BOOLEAN);

    @slon_api_create_status(new_status, remote_account->@("id"), user);

    @slon_free(session, id);
    return new_status;
}

U0 @slon_activitypub_reblog_status(SlonHttpSession* session, JsonObject* o, JsonObject* reblogged_status)
{
    JsonObject* remote_account = @slon_api_account_by_remote_actor(o->@("actor_for_key_id"));
    if (!remote_account) {
        AdamLog("remote account is NULL");
        return;
    }

    reblogged_status->set("reblogs_count", reblogged_status->@("reblogs_count") + 1, JSON_NUMBER);
    @slon_db_save_status_to_disk(reblogged_status);

    JsonObject* new_status = Json.CreateObject(slon_mem_task);
    U8* id = @slon_api_generate_unique_id(session);

    new_status->set("id", id, JSON_STRING);
    new_status->set("in_reply_to_id", NULL, JSON_NULL);
    new_status->set("in_reply_to_account_id", NULL, JSON_NULL);
    new_status->set("content", "", JSON_STRING);
    new_status->set("created_at", o->o("request")->@("published"), JSON_STRING);
    new_status->set("visibility", "public", JSON_STRING);
    new_status->set("uri", reblogged_status->@("uri"), JSON_STRING);
    new_status->set("url", reblogged_status->@("url"), JSON_STRING);
    new_status->set("account", remote_account, JSON_OBJECT);
    // new_status->set("application", status_app, JSON_OBJECT);
    new_status->set("reblogs_count", 0, JSON_NUMBER);
    new_status->set("favourites_count", 0, JSON_NUMBER);
    new_status->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("tags", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("mentions", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("media_attachments", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    new_status->set("replies_count", 0, JSON_NUMBER);
    new_status->set("spoiler_text", "", JSON_STRING);
    new_status->set("sensitive", o->@("sensitive"), JSON_BOOLEAN);
    new_status->set("reblog", reblogged_status, JSON_OBJECT);

    @slon_api_create_status(new_status, remote_account->@("id"), o->@("user"));

    @slon_free(session, id);
}

U0 @slon_activitypub_async_announce_request(JsonObject* o)
{
    Sleep(2000);
    if (!o) {
        return;
    }

    U8* reblogged_status_uri = o->o("request")->@("object");
    U8* reblogged_status_actor = StrNew(reblogged_status_uri, slon_mem_task);
    StrFind("/statuses/", reblogged_status_actor)[0] = NULL;

    // Does the user exist on this server? If yes, retrieve; if not, fetch and create them
    JsonObject* reblogged_status_account = @slon_activitypub_get_account_for_remote_actor(SLON_AP_DUMMY_SESSION, reblogged_status_actor);
    if (!reblogged_status_account) {
        // FIXME: We probably should handle this, or not.. it will just stay queued and retry until we Accept
        return;
    }

    // Fetch the status to be reblogged
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);
    U8* signatory = db->o("actors")->o(o->@("user"))->@("id");
    @http_response* resp = @slon_activitypub_signed_request(reblogged_status_uri, fetch_buffer, NULL, SLON_HTTP_VERB_GET, signatory);

    // AdamLog("code: %d\n", resp->status.code);

    // Create the status if it does not already exist on this server
    JsonObject* remote_status = Json.Parse(resp->body.data, slon_db_mem_task);
    JsonObject* reblog_status = @slon_activitypub_create_status_for_remote_account(SLON_AP_DUMMY_SESSION, reblogged_status_account, remote_status);

    AdamLog("reblog_status: %s\n", Json.Stringify(reblog_status, slon_mem_task));

    // Create the reblog
    @slon_activitypub_reblog_status(SLON_AP_DUMMY_SESSION, o, reblog_status);

    // Send the Accept request
    Spawn(&@slon_activitypub_async_accept_request, o, "SlonAsyncAcceptTask");

    Free(fetch_buffer);
}

U0 @slon_activitypub_users_inbox(SlonHttpSession* session, U8* user)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    I64 i, j;
    JsonObject* account = @slon_api_account_by_username(user);

    Bool already_following = FALSE;
    JsonArray* followers = NULL;
    JsonArray* statuses = NULL;

    JsonObject* status = NULL;

    JsonObject* request_object = NULL;
    U8* status_id = NULL;

    if (!StrICmp("announce", request_json->@("type"))) {
        if (StrICmp(session->actor_for_key_id, request_json->@("actor")) || !@slon_api_user_is_following(user, session->actor_for_key_id)) {
            session->status(401);
            return;
        }

        JsonObject* announce = Json.CreateObject(slon_mem_task);
        announce->set("actor_for_key_id", session->actor_for_key_id, JSON_STRING);
        announce->set("user", user, JSON_STRING);
        announce->set("request", Json.Clone(request_json, slon_mem_task), JSON_OBJECT);
        Spawn(&@slon_activitypub_async_announce_request, announce, "SlonAsyncAnnounceTask");
        session->status(200);
        return;
    }

    if (!StrICmp("follow", request_json->@("type"))) {
        if (StrICmp(session->actor_for_key_id, request_json->@("actor"))) {
            session->status(401);
            return;
        }
        if (!db->o("followers")->@(user)) {
            db->o("followers")->set(user, Json.CreateArray(slon_mem_task), JSON_ARRAY);
        }
        followers = db->o("followers")->a(user);
        for (i = 0; i < followers->length; i++) {
            if (!StrCmp(request_json->@("actor"), followers->@(i))) {
                already_following = TRUE;
            }
        }
        if (!already_following) {
            followers->append(request_json->@("actor"), JSON_STRING);
            account->set("followers_count", account->@("followers_count") + 1);
            @slon_db_save_followers_to_disk;
            @slon_db_save_account_to_disk(account);
        }
        request_object = Json.Clone(request_json, slon_mem_task);
    }

    if (!StrICmp("create", request_json->@("type"))) {
        Bool should_accept = FALSE;

        // If actor_for_key_id is: someone user is following
        JsonArray* iter_following = db->o("following")->a(user);
        if (iter_following) {
            for (i = 0; i < iter_following->length; i++) {
                if (!StrICmp(session->actor_for_key_id, iter_following->@(i))) {
                    should_accept = TRUE;
                    break;
                }
            }
        }

        // or, actor_for_key_id is: creating object to:, cc: user
        JsonArray* iter_actors = NULL;
        if (!should_accept) {
            JsonObject* me_actor = db->o("actors")->@(user);
            if (me_actor) {
                iter_actors = request_json->o("object")->a("to");
                if (iter_actors) {
                    for (i = 0; i < iter_actors->length; i++) {
                        if (!StrICmp(me_actor->@("id"), iter_actors->@(i))) {
                            should_accept = TRUE;
                            break;
                        }
                    }
                }
                iter_actors = request_json->o("object")->a("cc");
                if (iter_actors) {
                    for (i = 0; i < iter_actors->length; i++) {
                        if (!StrICmp(me_actor->@("id"), iter_actors->@(i))) {
                            should_accept = TRUE;
                            break;
                        }
                    }
                }
            }
        }

        // or, actor_for_key_id is: creating object to:, cc: someone user is following
        if (!should_accept && iter_following) {
            iter_actors = request_json->o("object")->a("to");
            if (iter_actors) {
                for (i = 0; i < iter_actors->length; i++) {
                    for (j = 0; j < iter_following->length; j++) {
                        if (!StrICmp(iter_actors->@(i), iter_following->@(j))) {
                            should_accept = TRUE;
                            break;
                        }
                    }
                }
            }
        }
        if (!should_accept && iter_following) {
            iter_actors = request_json->o("object")->a("cc");
            if (iter_actors) {
                for (i = 0; i < iter_actors->length; i++) {
                    for (j = 0; j < iter_following->length; j++) {
                        if (!StrICmp(iter_actors->@(i), iter_following->@(j))) {
                            should_accept = TRUE;
                            break;
                        }
                    }
                }
            }
        }

        // otherwise, 401
        if (!should_accept) {
            session->status(401);
            return;
        }

        JsonObject* remote_account = @slon_activitypub_get_account_for_remote_actor(session, request_json->@("actor"));
        if (!remote_account) {
            session->status(500);
            return;
        }

        @slon_activitypub_create_status_for_remote_account(session, remote_account, request_json->o("object"), account, user);

        request_object = Json.CreateObject(slon_mem_task);
        request_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
        request_object->set("id", request_json->@("id"), JSON_STRING);
        request_object->set("type", request_json->@("type"), JSON_STRING);
        request_object->set("actor", request_json->@("actor"), JSON_STRING);
        request_object->set("object", db->o("actors")->o(user)->@("id"), JSON_STRING);
    }

    if (!StrICmp("like", request_json->@("type"))) {
        if (StrICmp(session->actor_for_key_id, request_json->@("actor"))) {
            session->status(401);
            return;
        }
        status_id = StrFind("/", StrFind("/statuses/", request_json->@("object")) + 1) + 1;
        statuses = db->o("statuses")->a(account->@("id"));
        for (i = 0; i < statuses->length; i++) {
            status = statuses->@(i);
            if (!StrICmp(status_id, status->@("id"))) {
                // TODO: https://docs.joinmastodon.org/methods/statuses/#favourited_by
                status->set("favourites_count", status->@("favourites_count") + 1);
                break;
            }
        }
        @slon_db_save_status_to_disk(status);
        request_object = Json.Clone(request_json, slon_mem_task);
    }

    if (request_object) {
        JsonObject* o = Json.CreateObject(slon_mem_task);
        o->set("actor_for_key_id", session->actor_for_key_id, JSON_STRING);
        o->set("user", user, JSON_STRING);
        o->set("request", request_object, JSON_OBJECT);
        Spawn(&@slon_activitypub_async_accept_request, o, "SlonAsyncAcceptTask");
    }

    session->status(200);
    return;
}

U0 @slon_activitypub_users_post(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (session->path_count() < 3) {
        session->status(400);
        goto slon_activitypub_users_post_return;
    }

    U8* user = session->path(1);
    JsonObject* actor = db->o("actors")->@(user);
    if (!actor) {
        session->status(404);
        goto slon_activitypub_users_post_return;
    }

    U8* method = session->path(2);
    if (!StrICmp("inbox", method)) {
        if (!request_json) {
            session->status(400);
            goto slon_activitypub_users_post_return;
        }
        if (!request_json->@("type")) {
            session->status(400);
            goto slon_activitypub_users_post_return;
        }
        if (!StrICmp("delete", request_json->@("type"))) {
            session->status(400);
            goto slon_activitypub_users_post_return;
        }
        if (!@slon_activitypub_http_signature_is_valid(session, user)) {
            session->status(401);
            goto slon_activitypub_users_post_return;
        }
        @slon_activitypub_users_inbox(session, user);
        goto slon_activitypub_users_post_return;
    }

    session->status(404);

slon_activitypub_users_post_return:
    if (session->actor_for_key_id) {
        @slon_free(session, session->actor_for_key_id);
    }
}
