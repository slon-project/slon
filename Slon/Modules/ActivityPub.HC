U8* @slon_activitypub_strip_double_quotes(U8* str)
{
    while (str[0] == '"')
        str++;
    while (str[StrLen(str) - 1] == '"')
        str[StrLen(str) - 1] = NULL;
    return str;
}

Bool @slon_activitypub_http_signature_is_valid(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    // 1. Check that we have a signature and digest
    if (!StrLen(@slon_http_request_header(session, "signature")) || !StrLen(@slon_http_request_header(session, "digest"))) {
        AdamLog("[verify_signature] no signature or digest header present\n");
        return FALSE;
    }

    // 2. Check that digest 1) is SHA-256 and 2) matches content
    U8* request_digest = @slon_http_request_header(session, "digest");
    if (!(String.BeginsWith("SHA-256", request_digest) || String.BeginsWith("sha-256", request_digest))) {
        AdamLog("[verify_signature] digest is not SHA-256\n");
        return FALSE;
    }
    request_digest = StrFind("=", request_digest) + 1;
    I64 content_length = Str2I64(@slon_http_request_header(session, "content-length"));
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

    // Parse values from Signature header
    U8* signature_header = @slon_http_request_header(session, "signature");
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

    // 3. Confirm actor matches keyId
    if (!request_json->@("actor")) {
        AdamLog("[verify_signature] actor is not present in request\n");
        return FALSE;
    }
    if (!String.BeginsWith(request_json->@("actor"), keyId)) {
        AdamLog("[verify_signature] actor does not match keyId\n");
        return FALSE;
    }

    // Check if public key is cached for keyId, if not, fetch it
    if (!db->o("public_keys")->@(keyId)) {

        @slon_log(LOG_HTTPD, "Actor's public key is not cached, attempting to fetch");

        HttpUrl* url = @http_parse_url(request_json->@("actor"));
        if (!url) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, malformed url or unspecified error");
            return FALSE;
        }

        U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
        JsonObject* http_headers = Json.CreateObject();
        http_headers->set("accept", "application/json", JSON_STRING);
        @http_response* resp = Http.Get(url, fetch_buffer, NULL, http_headers);

        if (!resp) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, invalid response from remote server");
            Free(fetch_buffer);
            return FALSE;
        }

        while (resp->state != HTTP_STATE_DONE) {
            Sleep(1);
        }

        if (!resp->body.length) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, empty response from remote server");
            Free(fetch_buffer);
            return FALSE;
        }

        Free(fetch_buffer);

        JsonObject* user_object = Json.Parse(resp->body.data);
        if (!user_object) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, user object not present in response from remote server");
            return FALSE;
        }

        JsonObject* pubkey_object = user_object->@("publicKey");
        if (!pubkey_object) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, publicKey object not present in user object");
            return FALSE;
        }

        if (!pubkey_object->@("id")) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, id not present in publicKey object");
            return FALSE;
        }
        if (!pubkey_object->@("owner")) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, owner not present in publicKey object");
            return FALSE;
        }
        if (!pubkey_object->@("publicKeyPem")) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, publicKeyPem not present in publicKey object");
            return FALSE;
        }

        if (StrICmp(pubkey_object->@("id"), keyId)) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, keyId does not match id present in publicKey object");
            return FALSE;
        }
        if (StrICmp(pubkey_object->@("owner"), request_json->@("actor"))) {
            @slon_log(LOG_HTTPD, "Could not fetch actor's public key, actor does not match owner present in publicKey object");
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
        JsonObject* cached_key = Json.CreateObject();
        cached_key->set("key", der_buf, JSON_NUMBER);
        cached_key->set("length", der_buf_length, JSON_NUMBER);
        db->o("public_keys")->set(keyId, cached_key, JSON_OBJECT);

        @slon_free(session, pem_single_line);

        Json.Delete(user_object);
        Json.Delete(http_headers);
    }

    // Calculate our signature string allocation
    I64 sig_string_alloc_length = 0;

    I64 headers_split_count = 0;
    U8** headers_split = String.Split(headers, ' ', &headers_split_count);
    i = 0;
    while (i < headers_split_count) {
        sig_string_alloc_length += StrLen(@slon_http_request_header(session, headers_split[i]));
        ++i;
    }
    sig_string_alloc_length += StrLen(@slon_http_request_verb(session));
    sig_string_alloc_length += StrLen(@slon_http_request_path(session));
    sig_string_alloc_length *= 2;

    // Construct our signature string
    U8* sig_string = @slon_calloc(session, sig_string_alloc_length);
    i = 0;
    while (i < headers_split_count) {
        if (StrLen(headers_split[i]) && headers_split[i][0] >= 'A' && headers_split[i][0] <= 'Z') {
            headers_split[i][0] += 'a' - headers_split[i][0];
        }
        if (!StrCmp("(request-target)", headers_split[i])) {
            String.Append(sig_string, "(request-target): %s %s", "post", @slon_http_request_path(session));
        } else {
            String.Append(sig_string, "%s: %s", headers_split[i], @slon_http_request_header(session, headers_split[i]));
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
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
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
    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);
    if (path_segments_count == 3) {
        JsonObject* actor = db->o("actors")->@(path_segments[1]);
        if (actor) {
            @slon_http_send_ap_json(session, actor);
        } else {
            @slon_http_set_status_code(session, 404);
        }
    } else {
        @slon_http_set_status_code(session, 400);
    }
slon_activitypub_users_get_return:
    @slon_free(session, path);
}

U0 @slon_activitypub_async_accept_request(JsonObject* o)
{
    JsonObject* request = o->o("request");
    if (!StrICmp("accept", request->@("type")) || !StrICmp("reject", request->@("type"))) {
        return;
    }

    Sleep(2000);

    U8 scratch_buffer[2048];

    U8* this_actor = db->o("actors")->o(o->@("user"))->@("id");

    StrPrint(scratch_buffer, "%s/accept/%d", this_actor, Now);
    JsonObject* accept_object = Json.CreateObject();
    accept_object->set("@context", request->@("@context"), JSON_STRING);
    accept_object->set("id", scratch_buffer, JSON_STRING);
    accept_object->set("type", "Accept", JSON_STRING);
    accept_object->set("actor", this_actor, JSON_STRING);
    accept_object->set("object", request, JSON_OBJECT);

    U8* accept_object_s = Json.Stringify(accept_object);

    U8 content_hash[512];
    calc_sha_256(content_hash, accept_object_s, StrLen(accept_object_s));
    U8* computed_digest = @base64_encode(content_hash, 32);

    JsonObject* http_headers = Json.CreateObject();

    StrPrint(scratch_buffer, "%s/inbox", request->@("actor"));
    HttpUrl* url = @http_parse_url(scratch_buffer);

    CDateStruct ds;
    Date2Struct(&ds, Now + 1043910000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
    http_headers->set("Digest", scratch_buffer, JSON_STRING);

    http_headers->set("Content-Type", "application/activity+json", JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): post %s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s\n", http_headers->@("Date"));
    String.Append(scratch_buffer, "digest: %s\n", http_headers->@("Digest"));
    String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);

    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", this_actor) + 7;
    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject();
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", this_actor);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date digest content-type\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    @http_response* resp = Http.Post(url, fetch_buffer, accept_object_s, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not POST Accept, invalid response from remote server");
        Free(fetch_buffer);
        return;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    AdamLog("code: %d\n", resp->status.code);

    Free(fetch_buffer);
}

U0 @slon_activitypub_follow_request()
{

    U8 scratch_buffer[2048];

    U8* this_actor = "https://error.checksum.fail/users/alec";

    StrPrint(scratch_buffer, "%s/follow/%d", this_actor, Now);
    JsonObject* follow_object = Json.CreateObject();
    follow_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    follow_object->set("id", scratch_buffer, JSON_STRING);
    follow_object->set("type", "Follow", JSON_STRING);
    follow_object->set("actor", this_actor, JSON_STRING);
    follow_object->set("object", "https://techhub.social/users/ryeucrvtexw3", JSON_STRING);

    U8* follow_object_s = Json.Stringify(follow_object);

    U8 content_hash[512];
    calc_sha_256(content_hash, follow_object_s, StrLen(follow_object_s));
    U8* computed_digest = @base64_encode(content_hash, 32);

    JsonObject* http_headers = Json.CreateObject();

    StrPrint(scratch_buffer, "%s/inbox", "https://techhub.social/users/ryeucrvtexw3");
    HttpUrl* url = @http_parse_url(scratch_buffer);

    CDateStruct ds;
    Date2Struct(&ds, Now + 1043910000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
    http_headers->set("Digest", scratch_buffer, JSON_STRING);

    http_headers->set("Content-Type", "application/activity+json", JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): post %s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s\n", http_headers->@("Date"));
    String.Append(scratch_buffer, "digest: %s\n", http_headers->@("Digest"));
    String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);

    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", this_actor) + 7;
    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject();
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", this_actor);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date digest content-type\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    @http_response* resp = Http.Post(url, fetch_buffer, follow_object_s, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not POST Accept, invalid response from remote server");
        Free(fetch_buffer);
        return;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    AdamLog("code: %d\n", resp->status.code);

    Free(fetch_buffer);
}

U0 @slon_activitypub_async_create_status(JsonObject* status)
{
    Sleep(2000);
    U8 scratch_buffer[2048];

    U8* dest = "https://techhub.social/users/ryeucrvtexw3/inbox";
    U8* this_actor = StrNew(status->@("uri"), adam_task);
    StrFind("/statuses/", this_actor)[0] = NULL;

    JsonObject* create_object = Json.CreateObject();

    create_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    StrPrint(scratch_buffer, "%s/activity", status->@("uri"));
    create_object->set("id", scratch_buffer, JSON_STRING);
    create_object->set("type", "Create", JSON_STRING);
    create_object->set("actor", this_actor, JSON_STRING);
    create_object->set("published", status->@("created_at"), JSON_STRING);
    create_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]"), JSON_ARRAY);
    JsonArray* cc = Json.CreateArray();
    StrPrint(scratch_buffer, "%s/followers", this_actor);
    cc->append(Json.CreateItem(scratch_buffer, JSON_STRING));
    create_object->set("cc", cc, JSON_ARRAY);

    JsonObject* note_object = Json.CreateObject();
    note_object->set("id", status->@("uri"), JSON_STRING);
    note_object->set("type", "Note", JSON_STRING);
    note_object->set("summary", NULL, JSON_NULL);
    note_object->set("inReplyTo", NULL, JSON_NULL);
    note_object->set("published", status->@("created_at"), JSON_STRING);
    note_object->set("attributedTo", this_actor, JSON_STRING);
    note_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]"), JSON_ARRAY);
    note_object->set("cc", cc, JSON_ARRAY);
    note_object->set("sensitive", status->@("sensitive"), JSON_BOOLEAN);
    note_object->set("atomUri", status->@("uri"), JSON_STRING);
    note_object->set("inReplyToAtomUri", NULL, JSON_NULL);
    note_object->set("content", status->@("content"), JSON_STRING);
    JsonObject* content_map = Json.CreateObject();
    content_map->set("en", status->@("content"), JSON_STRING);
    note_object->set("contentMap", content_map, JSON_OBJECT);
    note_object->set("attachment", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    note_object->set("tag", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    note_object->set("replies", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);
    note_object->set("likes", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);
    note_object->set("shares", SLON_EMPTY_JSON_OBJECT, JSON_OBJECT);

    create_object->set("object", note_object, JSON_OBJECT);
    U8* create_object_s = Json.Stringify(create_object);

    U8 content_hash[512];
    calc_sha_256(content_hash, create_object_s, StrLen(create_object_s));
    U8* computed_digest = @base64_encode(content_hash, 32);

    JsonObject* http_headers = Json.CreateObject();

    HttpUrl* url = @http_parse_url(dest);

    CDateStruct ds;
    Date2Struct(&ds, Now + 1043910000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
    http_headers->set("Digest", scratch_buffer, JSON_STRING);

    http_headers->set("Content-Type", "application/activity+json", JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): post %s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s\n", http_headers->@("Date"));
    String.Append(scratch_buffer, "digest: %s\n", http_headers->@("Digest"));
    String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);

    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", this_actor) + 7;
    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject();
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", this_actor);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date digest content-type\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    @http_response* resp = Http.Post(url, fetch_buffer, create_object_s, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not POST Accept, invalid response from remote server");
        Free(fetch_buffer);
        return;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    AdamLog("code: %d\n", resp->status.code);

    Free(fetch_buffer);
}

U0 @slon_activitypub_async_delete_status(JsonObject* status)
{
    Sleep(2000);
    U8 scratch_buffer[2048];

    U8* dest = "https://techhub.social/users/ryeucrvtexw3/inbox";
    U8* this_actor = StrNew(status->@("uri"), adam_task);
    StrFind("/statuses/", this_actor)[0] = NULL;

    JsonObject* delete_object = Json.CreateObject();

    delete_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
    StrPrint(scratch_buffer, "%s#delete", status->@("uri"));
    delete_object->set("id", scratch_buffer, JSON_STRING);
    delete_object->set("type", "Delete", JSON_STRING);
    delete_object->set("actor", this_actor, JSON_STRING);
    delete_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]"), JSON_ARRAY);

    JsonObject* ts_object = Json.CreateObject();
    ts_object->set("id", status->@("uri"), JSON_STRING);
    ts_object->set("type", "Tombstone", JSON_STRING);
    ts_object->set("atomUri", status->@("uri"), JSON_STRING);

    delete_object->set("object", ts_object, JSON_OBJECT);
    U8* delete_object_s = Json.Stringify(delete_object);

    U8 content_hash[512];
    calc_sha_256(content_hash, delete_object_s, StrLen(delete_object_s));
    U8* computed_digest = @base64_encode(content_hash, 32);

    JsonObject* http_headers = Json.CreateObject();

    HttpUrl* url = @http_parse_url(dest);

    CDateStruct ds;
    Date2Struct(&ds, Now + 1043910000);
    StrPrint(scratch_buffer, "%03tZ, %02d %03tZ %04d %02d:%02d:%02d GMT", ds.day_of_week, "ST_DAYS_OF_WEEK", ds.day_of_mon, ds.mon - 1, "ST_MONTHS",
        ds.year, ds.hour, ds.min, ds.sec);
    http_headers->set("Date", scratch_buffer, JSON_STRING);

    StrPrint(scratch_buffer, "SHA-256=%s", computed_digest);
    http_headers->set("Digest", scratch_buffer, JSON_STRING);

    http_headers->set("Content-Type", "application/activity+json", JSON_STRING);

    StrPrint(scratch_buffer, "");
    String.Append(scratch_buffer, "(request-target): post %s\n", url->path);
    String.Append(scratch_buffer, "host: %s\n", url->host);
    String.Append(scratch_buffer, "date: %s\n", http_headers->@("Date"));
    String.Append(scratch_buffer, "digest: %s\n", http_headers->@("Digest"));
    String.Append(scratch_buffer, "content-type: %s", http_headers->@("Content-Type"));

    AdamLog("headers_to_sign:\n```%s```\n", scratch_buffer);

    calc_sha_256(content_hash, scratch_buffer, StrLen(scratch_buffer));

    U8* user = StrFind("/users/", this_actor) + 7;
    JsonObject* private_key_binary = db->o("private_keys_binary")->o(user);
    if (!private_key_binary) {
        I64 private_key_binary_size = 0;
        private_key_binary = Json.CreateObject();
        private_key_binary->set("data", @base64_decode(db->o("private_keys")->@(user), &private_key_binary_size), JSON_OBJECT);
        private_key_binary->set("size", private_key_binary_size, JSON_NUMBER);
        db->o("private_keys_binary")->set(user, private_key_binary, JSON_OBJECT);
    }

    I64 res;

    // Import RSA key
    U64 rsa_key = CAlloc(sizeof(U64) * 32, adam_task);
    res = @rsa_import(private_key_binary->@("data"), private_key_binary->@("size"), rsa_key);
    AdamLog("@rsa_import: res: %d\n", res);

    U8 sig[256];
    U64 siglen = 256;
    res = @rsa_create_signature(sig, &siglen, content_hash, 32, rsa_key);
    AdamLog("@rsa_create_signature: res: %d\n", res);
    U8* computed_sig = @base64_encode(sig, 256);

    StrCpy(scratch_buffer, "");
    String.Append(scratch_buffer, "keyId=\"%s#main-key\",", this_actor);
    String.Append(scratch_buffer, "algorithm=\"rsa-sha256\",");
    String.Append(scratch_buffer, "headers=\"(request-target) host date digest content-type\",");
    String.Append(scratch_buffer, "signature=\"%s\"", computed_sig);
    http_headers->set("Signature", scratch_buffer, JSON_STRING);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    @http_response* resp = Http.Post(url, fetch_buffer, delete_object_s, http_headers);

    if (!resp) {
        @slon_log(LOG_HTTPD, "Could not POST Accept, invalid response from remote server");
        Free(fetch_buffer);
        return;
    }

    while (resp->state != HTTP_STATE_DONE) {
        Sleep(1);
    }

    AdamLog("code: %d\n", resp->status.code);

    Free(fetch_buffer);
}

U0 @slon_activitypub_create_status_fedi(JsonObject* status)
{
    Spawn(&@slon_activitypub_async_create_status, status, "SlonAsyncCreateTask");
}

U0 @slon_activitypub_delete_status_fedi(JsonObject* status)
{
    Spawn(&@slon_activitypub_async_delete_status, status, "SlonAsyncDeleteTask");
}

@slon_api_status_create_fedi = &@slon_activitypub_create_status_fedi;
@slon_api_status_delete_fedi = &@slon_activitypub_delete_status_fedi;

JsonObject* @slon_activitypub_get_account_for_remote_actor(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    U8* remote_actor = request_json->@("actor");
    JsonObject* account = @slon_api_account_by_remote_actor(remote_actor);

    if (account) {
        return account;
    }
    account = Json.CreateObject();

    HttpUrl* url = @http_parse_url(remote_actor);
    if (!url) {
        @slon_log(LOG_HTTPD, "Could not fetch actor, malformed url or unspecified error");
        return NULL;
    }

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    JsonObject* http_headers = Json.CreateObject();
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

    Free(fetch_buffer);

    JsonObject* actor_object = Json.Parse(resp->body.data);

    U8* id = @slon_api_generate_unique_id(session);
    U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

    account->set("id", id, JSON_STRING);
    account->set("created_at", created_at, JSON_STRING);
    account->set("username", actor_object->@("preferredUsername"), JSON_STRING);
    StrPrint(scratch_buffer, "%s@%s", actor_object->@("preferredUsername"), url->host);
    account->set("acct", scratch_buffer, JSON_STRING);
    account->set("display_name", actor_object->@("name"), JSON_STRING);
    account->set("email", "", JSON_STRING);
    account->set("note", actor_object->@("summary"), JSON_STRING);
    if (actor_object->@("icon")) {
        account->set("avatar", actor_object->o("icon")->@("url"), JSON_STRING);
        account->set("avatar_static", actor_object->o("icon")->@("url"), JSON_STRING);
    } else {
        account->set("avatar", SLON_MISSING_ACCOUNT_AVATAR, JSON_STRING);
        account->set("avatar_static", SLON_MISSING_ACCOUNT_AVATAR, JSON_STRING);
    }
    account->set("header", "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==", JSON_STRING);
    account->set("header_static", "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==", JSON_STRING);
    account->set("last_status_at", "0", JSON_STRING);
    account->set("followers_count", 0, JSON_NUMBER);
    account->set("following_count", 0, JSON_NUMBER);
    account->set("statuses_count", 0, JSON_NUMBER);
    account->set("locked", FALSE, JSON_BOOLEAN);
    account->set("bot", FALSE, JSON_BOOLEAN);
    account->set("discoverable", FALSE, JSON_BOOLEAN);
    account->set("indexable", FALSE, JSON_BOOLEAN);
    account->set("hide_collections", FALSE, JSON_BOOLEAN);
    account->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    account->set("fields", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    account->set("url", remote_actor, JSON_STRING);
    account->set("remote_actor", remote_actor, JSON_STRING);

    db->a("accounts")->append(Json.CreateItem(account, JSON_OBJECT));
    // db->o("statuses")->set(acct->@("id"), Json.CreateArray(), JSON_ARRAY);
    @slon_db_save_to_disk;

    @slon_free(session, created_at);
    @slon_free(session, id);

    return account;
}

U0 @slon_activitypub_users_inbox(SlonHttpSession* session, U8* user)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    I64 i;
    JsonObject* account = @slon_api_account_by_username(user);

    Bool already_following = FALSE;
    JsonArray* followers = NULL;
    JsonArray* statuses = NULL;

    JsonObject* status = NULL;

    JsonObject* request_object = NULL;

    if (!StrICmp("follow", request_json->@("type"))) {
        if (!db->o("followers")->@(user)) {
            db->o("followers")->set(user, Json.CreateArray(), JSON_ARRAY);
        }
        followers = db->o("followers")->a(user);
        for (i = 0; i < followers->length; i++) {
            if (!StrCmp(request_json->@("actor"), followers->@(i))) {
                already_following = TRUE;
            }
        }
        if (!already_following) {
            followers->append(Json.CreateItem(request_json->@("actor"), JSON_STRING));
            account->set("followers_count", account->@("followers_count") + 1);
            @slon_db_save_to_disk;
        }
        request_object = Json.Clone(request_json);
    }

    if (!StrICmp("create", request_json->@("type"))) {
        JsonObject* remote_account = @slon_activitypub_get_account_for_remote_actor(session);

        JsonObject* new_status = Json.CreateObject();
        U8* id = @slon_api_generate_unique_id(session);

        JsonArray* media_attachments = Json.CreateArray();
        if (request_json->o("object")->@("attachment")) {
            JsonObject* attachment_item = NULL;
            JsonObject* media_attachment = NULL;
            JsonObject* media_meta = NULL;
            JsonArray* attachment_array = request_json->o("object")->@("attachment");
            for (i = 0; i < attachment_array->length; i++) {
                attachment_item = attachment_array->o(i);
                if (attachment_item && attachment_item->@("mediaType") && String.BeginsWith("image", attachment_item->@("mediaType"))) {
                    media_attachment = Json.CreateObject();
                    media_meta = Json.CreateObject();
                    media_attachment->set("id", "", JSON_STRING);
                    media_attachment->set("type", "image", JSON_STRING);
                    media_attachment->set("url", attachment_item->@("url"), JSON_STRING);
                    media_attachment->set("preview_url", NULL, JSON_NULL);
                    media_attachment->set("remote_url", NULL, JSON_NULL);
                    if (attachment_item->@("width") && attachment_item->@("height")) {
                        media_meta->set("original", Json.CreateObject(), JSON_OBJECT);
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
                    media_attachments->append(Json.CreateItem(media_attachment, JSON_OBJECT));
                }
            }
        }

        new_status->set("id", id, JSON_STRING);
        new_status->set("created_at", request_json->@("published"), JSON_STRING);
        new_status->set("content", request_json->o("object")->@("content"), JSON_STRING);
        new_status->set("visibility", "public", JSON_STRING);
        new_status->set("uri", request_json->o("object")->@("atomUri"), JSON_STRING);
        new_status->set("url", request_json->o("object")->@("url"), JSON_STRING);
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
        new_status->set("sensitive", request_json->o("object")->@("sensitive"), JSON_BOOLEAN);

        if (!db->o("timelines")->o("home")->a(account->@("id"))) {
            db->o("timelines")->o("home")->set(account->@("id"), Json.CreateArray(), JSON_ARRAY);
        }
        db->o("timelines")->o("home")->a(account->@("id"))->append(Json.CreateItem(new_status, JSON_OBJECT));

        @slon_db_save_timelines_to_disk;
        @slon_free(session, id);
        request_object = Json.CreateObject();
        request_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
        request_object->set("id", request_json->@("id"), JSON_STRING);
        request_object->set("type", request_json->@("type"), JSON_STRING);
        request_object->set("actor", request_json->@("actor"), JSON_STRING);
        request_object->set("object", db->o("actors")->o(user)->@("id"), JSON_STRING);
    }

    if (!StrICmp("like", request_json->@("type"))) {
        U8* status_id = StrFind("/", StrFind("/statuses/", request_json->@("object")) + 1) + 1;
        statuses = db->o("statuses")->a(account->@("id"));
        for (i = 0; i < statuses->length; i++) {
            status = statuses->@(i);
            if (!StrICmp(status_id, status->@("id"))) {
                status->set("favourites_count", status->@("favourites_count") + 1);
                break;
            }
        }
        @slon_db_save_statuses_to_disk;
        request_object = Json.Clone(request_json);
    }

    if (request_object) {
        JsonObject* o = Json.CreateObject();
        o->set("user", user, JSON_STRING);
        o->set("request", request_object, JSON_OBJECT);
        Spawn(&@slon_activitypub_async_accept_request, o, "SlonAsyncAcceptTask");
    }

    @slon_http_set_status_code(session, 200);
    return;
}

U0 @slon_activitypub_users_post(SlonHttpSession* session)
{
    if (!@slon_activitypub_http_signature_is_valid(session)) {
        @slon_http_set_status_code(session, 401);
        return;
    }

    U8* path = @slon_strnew(session, @slon_http_request_path(session));
    I64 path_segments_count = 0;
    U8** path_segments = String.Split(path, '/', &path_segments_count);

    if (path_segments_count < 3) {
        @slon_http_set_status_code(session, 400);
        goto slon_activitypub_users_post_return;
    }

    U8* user = path_segments[1];
    JsonObject* actor = db->o("actors")->@(user);
    if (!actor) {
        @slon_http_set_status_code(session, 404);
        goto slon_activitypub_users_post_return;
    }

    U8* method = path_segments[2];
    if (!StrICmp("inbox", method)) {
        @slon_activitypub_users_inbox(session, user);
        goto slon_activitypub_users_post_return;
    }

    @slon_http_set_status_code(session, 404);

slon_activitypub_users_post_return:
    @slon_free(session, path);
}
