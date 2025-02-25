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

    // Check if public key is cached for keyId, if not, fetch it
    if (!db->o("public_keys")->@(keyId)) {

        @slon_log(LOG_HTTPD, "Signatory's public key is not cached, attempting to fetch");

        U8* signatory_url_string = @slon_strnew(session, keyId);
        StrFind("#", signatory_url_string)[0] = NULL;

        U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
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

        JsonObject* user_object = Json.Parse(resp->body.data);
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
        JsonObject* cached_key = Json.CreateObject();
        cached_key->set("key", der_buf, JSON_NUMBER);
        cached_key->set("length", der_buf_length, JSON_NUMBER);
        db->o("public_keys")->set(keyId, cached_key, JSON_OBJECT);

        @slon_free(session, pem_single_line);

        Json.Delete(user_object);
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

    JsonObject* http_headers = Json.CreateObject();

    U8 scratch_buffer[2048];
    U8* request_object_s = NULL;

    if (request_object) {
        signatory = request_object->@("actor");
        request_object_s = Json.Stringify(request_object);
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
    Date2Struct(&ds, Now + 1043910000);
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

    AdamLog("code: %d\n", resp->status.code);

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
    JsonObject* accept_object = Json.CreateObject();
    accept_object->set("@context", request->@("@context"), JSON_STRING);
    accept_object->set("id", scratch_buffer, JSON_STRING);
    accept_object->set("type", "Accept", JSON_STRING);
    accept_object->set("actor", this_actor, JSON_STRING);
    accept_object->set("object", request, JSON_OBJECT);

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    StrPrint(scratch_buffer, "%s/inbox", o->@("actor_for_key_id"));
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, accept_object);
    Free(fetch_buffer);
    Json.Delete(accept_object);
}

U0 @slon_activitypub_async_create_status_to(JsonObject* status, U8* dest)
{
    Sleep(1000);
    U8 scratch_buffer[2048];

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
    note_object->set("published", status->@("created_at"), JSON_STRING);
    note_object->set("attributedTo", this_actor, JSON_STRING);
    note_object->set("to", Json.Parse("[\"https://www.w3.org/ns/activitystreams#Public\"]"), JSON_ARRAY);
    note_object->set("cc", cc, JSON_ARRAY);
    note_object->set("sensitive", status->@("sensitive"), JSON_BOOLEAN);
    note_object->set("atomUri", status->@("uri"), JSON_STRING);
    if (status->@("in_reply_to_id")) {
        // lookup status uri in user's home timeline
        JsonArray* lookup_array = db->o("timelines")->o("home")->a(status->o("account")->@("id"));
        if (lookup_array) {
            I64 i;
            for (i = 0; i < lookup_array->length; i++) {
                if (!StrICmp(status->@("in_reply_to_id"), lookup_array->o(i)->@("id"))) {
                    note_object->set("inReplyTo", lookup_array->o(i)->@("uri"), JSON_STRING);
                    note_object->set("inReplyToAtomUri", lookup_array->o(i)->@("uri"), JSON_STRING);
                    break;
                }
            }
        }
    } else {
        note_object->set("inReplyTo", NULL, JSON_NULL);
        note_object->set("inReplyToAtomUri", NULL, JSON_NULL);
    }
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
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    StrPrint(scratch_buffer, "%s/inbox", dest);
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, create_object);
    Free(fetch_buffer);
    Json.Delete(create_object);
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
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    StrPrint(scratch_buffer, "%s/inbox", dest);
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, delete_object);
    Free(fetch_buffer);
    Json.Delete(delete_object);
}

U0 @slon_activitypub_async_follow(JsonObject* follow)
{
    Sleep(1000);
    U8 scratch_buffer[1024];
    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    StrPrint(scratch_buffer, "%s/inbox", follow->@("object"));
    @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, follow);
    Free(fetch_buffer);
    Json.Delete(follow);
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

JsonObject* @slon_activitypub_get_account_for_remote_actor(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

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

    JsonObject* actor_object = Json.Parse(resp->body.data);
    account = @slon_accounts_create_local_for_remote_actor(session, actor_object, remote_actor, url);
    Free(fetch_buffer);

    return account;
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

    if (!StrICmp("follow", request_json->@("type"))) {
        if (StrICmp(session->actor_for_key_id, request_json->@("actor"))) {
            session->status(401);
            return;
        }
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
            @slon_db_save_followers_to_disk;
            @slon_db_save_accounts_to_disk;
        }
        request_object = Json.Clone(request_json);
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

        if (db->o("timelines")->o("home")->a(account->@("id"))) {
            if (@slon_activitypub_status_exists(db->o("timelines")->o("home")->a(account->@("id")), request_json->o("object")->@("atomUri"))) {
                session->status(200);
                return;
            }
        }

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
        if (StrICmp(session->actor_for_key_id, request_json->@("actor"))) {
            session->status(401);
            return;
        }
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
