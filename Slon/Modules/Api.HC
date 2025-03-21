#define SLON_API_LOCAL_TIME_OFFSET 3550
#define SLON_AUTH_ACCOUNT_ID                         \
    U8* account_id = NULL;                           \
    if (session->auth) {                             \
        account_id = session->auth->@("account_id"); \
    };

SlonHttpSession* SLON_API_DUMMY_SESSION = CAlloc(sizeof(SlonHttpSession));
SLON_API_DUMMY_SESSION->mem_task = slon_mem_task;

extern @http_response* @slon_activitypub_signed_request(U8* url_string, U8* fetch_buffer, JsonObject* request_object = NULL, I64 verb = SLON_HTTP_VERB_POST, U8* signatory = NULL);

class SlonCatboxUpload {
    JsonKey* key;
    U8* filepath;
    U0 (*callback)(U64 arg = NULL);
    U64 callback_arg;
};

Bool @slon_api_authorized(SlonHttpSession* session)
{
    U8 scratch_buffer[256];
    U8* whitelist_ip = db->o("settings")->@("whitelist_ip");
    if (whitelist_ip) {
        StrPrint(scratch_buffer, "'%s'", session->header("x-forwarded-for"));
        return session->auth > 0 && StrFind(scratch_buffer, whitelist_ip);
    }
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

JsonObject* @slon_api_announcement_by_id(U8* id)
{
    if (!id || !StrLen(id))
        return NULL;
    JsonArray* announcements = db->a("announcements");
    I64 i;
    for (i = 0; i < announcements->length; i++) {
        if (!StrICmp(announcements->o(i)->@("id"), id)) {
            return announcements->o(i);
        }
    }
    return NULL;
}

JsonObject* @slon_api_status_lookup_by_id(U8* id, JsonArray* statuses)
{
    if (!id || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!status->@("deleted") && status->@("id") && !StrICmp(status->@("id"), id)) {
            return status;
        }
    }
    return NULL;
}

JsonObject* @slon_api_status_lookup_by_in_reply_to_id(U8* id, JsonArray* statuses)
{
    if (!id || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!status->@("deleted") && status->@("in_reply_to_id") && !StrICmp(status->@("in_reply_to_id"), id)) {
            return status;
        }
    }
    return NULL;
}

JsonObject* @slon_api_status_lookup_by_poll_id(U8* id, JsonArray* statuses)
{
    if (!id || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!status->@("deleted") && status->@("poll") && !StrICmp(status->o("poll")->@("id"), id)) {
            return status;
        }
    }
    return NULL;
}

JsonObject* @slon_api_status_lookup_by_uri(U8* uri, JsonArray* statuses)
{
    if (!uri || !statuses) {
        return NULL;
    }
    I64 i;
    JsonObject* status;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!status->@("deleted") && status->@("uri") && !StrICmp(status->@("uri"), uri)) {
            return status;
        }
    }
    return NULL;
}

JsonObject* @slon_api_find_status_by_id(U8* id, U8* account_id = NULL)
{
    if (account_id) {
        return @slon_api_status_lookup_by_id(id, db->o("statuses")->a(account_id));
    }
    JsonObject* status = NULL;
    JsonKey* key = db->o("statuses")->keys;
    while (key) {
        status = @slon_api_status_lookup_by_id(id, key->value);
        if (status) {
            return status;
        }
        key = key->next;
    }
    return NULL;
}

JsonObject* @slon_api_find_status_by_poll_id(U8* id, U8* account_id = NULL)
{
    if (account_id) {
        return @slon_api_status_lookup_by_poll_id(id, db->o("statuses")->a(account_id));
    }
    JsonObject* status = NULL;
    JsonKey* key = db->o("statuses")->keys;
    while (key) {
        status = @slon_api_status_lookup_by_poll_id(id, key->value);
        if (status) {
            return status;
        }
        key = key->next;
    }
    return NULL;
}

JsonObject* @slon_api_find_status_by_uri(U8* uri, U8* account_id = NULL)
{
    if (account_id) {
        return @slon_api_status_lookup_by_uri(uri, db->o("statuses")->a(account_id));
    }
    JsonObject* status = NULL;
    JsonKey* key = db->o("statuses")->keys;
    while (key) {
        status = @slon_api_status_lookup_by_uri(uri, key->value);
        if (status) {
            return status;
        }
        key = key->next;
    }
    return NULL;
}

U0 @slon_api_notify_account(JsonObject* target_acct, JsonObject* source_acct, U8* type, JsonObject* status = NULL)
{
    U8 scratch_buffer[256];
    SlonHttpSession* session = SLON_API_DUMMY_SESSION;

    U8* id = @slon_api_generate_unique_id(session);
    U8* created_at = @slon_api_timestamp_from_cdate(session, Now);

    if (!db->o("notifications")->@(target_acct->@("username"))) {
        db->o("notifications")->set(target_acct->@("username"), Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
    }

    JsonArray* notifications = db->o("notifications")->a(target_acct->@("username"));

    JsonObject* notification = Json.CreateObject(slon_db_mem_task);
    notification->set("id", id, JSON_STRING);
    notification->set("type", type, JSON_STRING);
    notification->set("created_at", created_at, JSON_STRING);
    StrPrint(scratch_buffer, "ungrouped-%s", id);
    notification->set("group_key", scratch_buffer, JSON_STRING);
    notification->set("account", source_acct, JSON_OBJECT);
    if (status) {
        notification->set("status", status, JSON_OBJECT);
    }
    notifications->append(notification);
    @slon_db_save_notifications_to_disk;
    @slon_free(session, created_at);
    @slon_free(session, id);
}

U0 @slon_api_create_status(JsonObject* status, U8* account_id, U8* to_ap_user = NULL)
{
    if (!status || !account_id) {
        return;
    }
    if (!db->o("statuses")->a(account_id)) {
        db->o("statuses")->set(account_id, Json.CreateArray(slon_mem_task), JSON_ARRAY);
    }
    db->o("statuses")->a(account_id)->append(status);
    @slon_db_save_status_to_disk(status);
    @slon_db_instance_increment_status_count;
    @slon_db_save_instance_to_disk;

    JsonObject* status_item = Json.CreateObject(slon_mem_task);
    status_item->set("account_id", account_id, JSON_STRING);
    status_item->set("status_id", status->@("id"), JSON_STRING);

    // If account_id is a local account, publish to public timeline
    JsonObject* acct = @slon_api_account_by_id(account_id);
    if (!acct->@("remote_actor") && !StrICmp("public", status->@("visibility"))) {
        if (!db->o("timelines")->a("public")) {
            db->o("timelines")->set("public", Json.CreateArray(slon_mem_task), JSON_ARRAY);
        }
        db->o("timelines")->a("public")->append(status_item);
    }
    // If account_id is a remote account, and we have an ActivityPub user, post to their timeline
    if (acct->@("remote_actor") && to_ap_user) {
        JsonObject* acct_for_ap_user = @slon_api_account_by_username(to_ap_user);
        if (acct_for_ap_user) {
            if (!db->o("timelines")->o("home")->a(acct_for_ap_user->@("id"))) {
                db->o("timelines")->o("home")->set(acct_for_ap_user->@("id"), Json.CreateArray(slon_mem_task), JSON_ARRAY);
            }
            db->o("timelines")->o("home")->a(acct_for_ap_user->@("id"))->append(status_item);
        }
    }
    @slon_db_save_timelines_to_disk;
}

Bool @slon_api_status_is_bookmarked(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* bookmarks = db->o("bookmarks")->a(account_id);
    JsonObject* bookmark = NULL;
    if (!bookmarks) {
        return FALSE;
    }
    I64 i;
    for (i = 0; i < bookmarks->length; i++) {
        bookmark = bookmarks->o(i);
        if (!StrICmp(bookmark->@("status_id"), status->@("id")) && !StrICmp(bookmark->@("account_id"), status->o("account")->@("id"))) {
            return TRUE;
        }
    }
    return FALSE;
}

JsonArray* @slon_api_status_poll_choices(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* votes = db->o("votes")->a(account_id);
    JsonObject* vote = NULL;
    if (!votes) {
        return NULL;
    }
    I64 i;
    for (i = 0; i < votes->length; i++) {
        vote = votes->o(i);
        if (!StrICmp(vote->@("status_id"), status->@("id")) && !StrICmp(vote->@("account_id"), account_id)) {
            return vote->a("choices");
        }
    }
    return NULL;
}

U0 @slon_api_bookmark_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    Bool is_already_bookmarked = FALSE;
    JsonArray* bookmarks = db->o("bookmarks")->a(account_id);
    JsonObject* bookmark = NULL;
    if (!bookmarks) {
        bookmarks = Json.CreateArray(slon_db_mem_task);
        db->o("bookmarks")->set(account_id, bookmarks, JSON_ARRAY);
    }
    I64 i;
    for (i = 0; i < bookmarks->length; i++) {
        bookmark = bookmarks->o(i);
        if (!StrICmp(bookmark->@("status_id"), status->@("id")) && !StrICmp(bookmark->@("account_id"), status->o("account")->@("id"))) {
            is_already_bookmarked = TRUE;
            break;
        }
    }
    if (!is_already_bookmarked) {
        bookmark = Json.CreateObject(slon_db_mem_task);
        bookmark->set("status_id", status->@("id"), JSON_STRING);
        bookmark->set("account_id", status->o("account")->@("id"), JSON_STRING);
        bookmarks->append(bookmark);
        @slon_db_save_bookmarks_to_disk;
    }
}

U0 @slon_api_unbookmark_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* bookmarks = db->o("bookmarks")->a(account_id);
    JsonObject* bookmark = NULL;
    if (!bookmarks) {
        bookmarks = Json.CreateArray(slon_db_mem_task);
        db->o("bookmarks")->set(account_id, bookmarks, JSON_ARRAY);
    }
    I64 i;
    for (i = 0; i < bookmarks->length; i++) {
        bookmark = bookmarks->o(i);
        if (!StrICmp(bookmark->@("status_id"), status->@("id")) && !StrICmp(bookmark->@("account_id"), status->o("account")->@("id"))) {
            bookmarks->remove(i);
            @slon_db_save_bookmarks_to_disk;
            break;
        }
    }
}

Bool @slon_api_status_is_favourited(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* favourites = db->o("favourites")->a(account_id);
    JsonObject* favourite = NULL;
    if (!favourites) {
        return FALSE;
    }
    I64 i;
    for (i = 0; i < favourites->length; i++) {
        favourite = favourites->o(i);
        if (!StrICmp(favourite->@("status_id"), status->@("id")) && !StrICmp(favourite->@("account_id"), status->o("account")->@("id"))) {
            return TRUE;
        }
    }
    return FALSE;
}

Bool @slon_api_status_is_reblogged(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* reblogs = db->o("reblogs")->a(account_id);
    JsonObject* reblog = NULL;
    if (!reblogs) {
        return FALSE;
    }
    I64 i;
    for (i = 0; i < reblogs->length; i++) {
        reblog = reblogs->o(i);
        if (!StrICmp(reblog->@("boost_id"), status->@("id")) || !StrICmp(reblog->@("status_id"), status->@("id"))) {
            return TRUE;
        }
    }
    return FALSE;
}

U0 @slon_api_favourite_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    Bool is_already_favourited = FALSE;
    JsonArray* favourites = db->o("favourites")->a(account_id);
    JsonObject* favourite = NULL;
    if (!favourites) {
        favourites = Json.CreateArray(slon_db_mem_task);
        db->o("favourites")->set(account_id, favourites, JSON_ARRAY);
    }
    I64 i;
    for (i = 0; i < favourites->length; i++) {
        favourite = favourites->o(i);
        if (!StrICmp(favourite->@("status_id"), status->@("id")) && !StrICmp(favourite->@("account_id"), status->o("account")->@("id"))) {
            is_already_favourited = TRUE;
            break;
        }
    }
    if (!is_already_favourited) {
        favourite = Json.CreateObject(slon_db_mem_task);
        favourite->set("status_id", status->@("id"), JSON_STRING);
        favourite->set("account_id", status->o("account")->@("id"), JSON_STRING);
        favourites->append(favourite);
        @slon_db_save_favourites_to_disk;
    }
}

U0 @slon_api_unfavourite_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* favourites = db->o("favourites")->a(account_id);
    JsonObject* favourite = NULL;
    if (!favourites) {
        favourites = Json.CreateArray(slon_db_mem_task);
        db->o("favourites")->set(account_id, favourites, JSON_ARRAY);
    }
    I64 i;
    for (i = 0; i < favourites->length; i++) {
        favourite = favourites->o(i);
        if (!StrICmp(favourite->@("status_id"), status->@("id")) && !StrICmp(favourite->@("account_id"), status->o("account")->@("id"))) {
            favourites->remove(i);
            @slon_db_save_favourites_to_disk;
            break;
        }
    }
}

JsonObject* @slon_api_reblog_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    Bool is_already_reblogged = FALSE;
    JsonArray* reblogs = db->o("reblogs")->a(account_id);
    JsonObject* reblog = NULL;
    if (!reblogs) {
        reblogs = Json.CreateArray(slon_db_mem_task);
        db->o("reblogs")->set(account_id, reblogs, JSON_ARRAY);
        @slon_db_save_reblogs_to_disk;
    }
    I64 i;
    for (i = 0; i < reblogs->length; i++) {
        reblog = reblogs->o(i);
        if (!StrICmp(reblog->@("status_id"), status->@("id")) && !StrICmp(reblog->@("account_id"), status->o("account")->@("id"))) {
            return @slon_api_find_status_by_id(reblog->@("boost_id"), account_id);
        }
    }

    // Create boost object, which is our reblog status with the original status attached as a "reblog" object
    JsonObject* boost = Json.CreateObject(slon_db_mem_task);
    U8* boost_id = @slon_api_generate_unique_id(session);
    U8* boost_created_at = @slon_api_timestamp_from_cdate(session, Now);

    boost->set("id", boost_id, JSON_STRING);
    boost->set("in_reply_to_id", NULL, JSON_NULL);
    boost->set("in_reply_to_account_id", NULL, JSON_NULL);
    boost->set("content", "", JSON_STRING);
    boost->set("created_at", boost_created_at, JSON_STRING);
    boost->set("visibility", "public", JSON_STRING);
    boost->set("uri", status->@("uri"), JSON_STRING);
    boost->set("url", status->@("url"), JSON_STRING);
    boost->set("account", @slon_api_account_by_id(account_id), JSON_OBJECT);
    boost->set("reblogs_count", 0, JSON_NUMBER);
    boost->set("favourites_count", 0, JSON_NUMBER);
    boost->set("emojis", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    boost->set("tags", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    boost->set("mentions", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    boost->set("media_attachments", SLON_EMPTY_JSON_ARRAY, JSON_ARRAY);
    boost->set("replies_count", 0, JSON_NUMBER);
    boost->set("spoiler_text", "", JSON_STRING);
    boost->set("sensitive", status->@("sensitive"), JSON_BOOLEAN);
    boost->set("reblog", status, JSON_OBJECT);

    @slon_api_create_status(boost, account_id);

    // Create a reblog object which is a lookup to status_id, account_id, boost_id
    reblog = Json.CreateObject(slon_db_mem_task);
    reblog->set("status_id", status->@("id"), JSON_STRING);
    reblog->set("account_id", status->o("account")->@("id"), JSON_STRING);
    reblog->set("boost_id", boost->@("id"), JSON_STRING);
    reblogs->append(reblog);
    @slon_db_save_reblogs_to_disk;

    status->set("reblogs_count", status->@("reblogs_count") + 1, JSON_NUMBER);
    @slon_db_save_status_to_disk(status);

    @slon_free(session, boost_created_at);
    @slon_free(session, boost_id);

    return boost;
}

U0 @slon_api_unreblog_status(SlonHttpSession* session, JsonObject* status, U8* account_id)
{
    no_warn session;
    JsonArray* reblogs = db->o("reblogs")->a(account_id);
    JsonObject* reblog = NULL;
    JsonObject* boost = NULL;
    if (!reblogs) {
        reblogs = Json.CreateArray(slon_db_mem_task);
        db->o("reblogs")->set(account_id, reblogs, JSON_ARRAY);
        @slon_db_save_reblogs_to_disk;
    }
    I64 i;
    for (i = 0; i < reblogs->length; i++) {
        reblog = reblogs->o(i);
        if (!StrICmp(reblog->@("status_id"), status->@("id")) && !StrICmp(reblog->@("account_id"), status->o("account")->@("id"))) {
            reblogs->remove(i);
            @slon_db_save_reblogs_to_disk;
            status->set("reblogs_count", status->@("reblogs_count") - 1, JSON_NUMBER);
            @slon_db_save_status_to_disk(status);
            boost = @slon_api_find_status_by_id(reblog->@("boost_id"), account_id);
            if (boost) {
                boost->set("deleted", TRUE, JSON_BOOLEAN);
                @slon_db_save_status_to_disk(status);
            }
            break;
        }
    }
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

    U8* payload = CAlloc(4096 + data_size, slon_mem_task);
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
    U8* headers = CAlloc(4096, slon_mem_task);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = CAlloc(send_buffer_size, slon_mem_task);

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
    U8* response_buffer = CAlloc(4096, slon_mem_task);

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

    cb->key->value = StrNew(url_ptr, slon_mem_task);
    cb->key->type = JSON_STRING;
    if (cb->callback) {
        cb->callback(cb->callback_arg);
    }

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

    U8* payload = CAlloc(4096, slon_mem_task);
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
    U8* headers = CAlloc(4096, slon_mem_task);
    String.Append(headers, "POST /user/api.php HTTP/1.1\r\n");
    String.Append(headers, "Host: catbox.moe\r\n");
    String.Append(headers, "User-Agent: slon/1.0\r\n");
    String.Append(headers, "Content-Length: %d\r\n", payload_size);
    String.Append(headers, "Content-Type: multipart/form-data; boundary=%s\r\n\r\n", boundary);

    I64 send_buffer_size = StrLen(headers) + payload_size;
    U8* send_buffer = CAlloc(send_buffer_size, slon_mem_task);

    MemCpy(send_buffer, headers, StrLen(headers));
    MemCpy(send_buffer + StrLen(headers), payload, payload_size);

    TlsSocket* s = @tls_socket_create("catbox.moe", 443);
    while (!@tls_established(s->ctx))
        Sleep(1);

    s->send(send_buffer, send_buffer_size);

    I64 bytes_received = 0;
    I64 response_buffer_size = 0;
    U8* response_buffer = CAlloc(4096, slon_mem_task);

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

JsonObject* @slon_api_get_timeline_item(JsonObject* timeline_item)
{
    if (!timeline_item) {
        return NULL;
    }
    JsonArray* statuses = db->o("statuses")->a(timeline_item->@("account_id"));
    JsonObject* status = NULL;
    if (!statuses) {
        return NULL;
    }
    I64 i;
    for (i = 0; i < statuses->length; i++) {
        status = statuses->@(i);
        if (!status->@("deleted") && !StrICmp(status->@("id"), timeline_item->@("status_id"))) {
            return status;
        }
    }
    return NULL;
}

JsonArray* @slon_api_status_array_from_timeline(JsonArray* timeline)
{
    if (!timeline) {
        return NULL;
    }
    JsonArray* status_array = Json.CreateArray(slon_mem_task);
    JsonObject* timeline_item = NULL;
    JsonObject* status = NULL;
    I64 i;
    for (i = 0; i < timeline->length; i++) {
        timeline_item = timeline->@(i);
        status = @slon_api_get_timeline_item(timeline_item);
        if (status) {
            status_array->append(status);
        }
    }
    return status_array;
}

Bool @slon_api_get_value_as_boolean(JsonKey* key)
{
    if (!key) {
        return FALSE;
    }
    switch (key->type) {
    case JSON_STRING:
        return key->value && !StrICmp("true", key->value);
    case JSON_BOOLEAN:
        return key->value;
    default:
        return FALSE;
    }
}

Bool @slon_api_user_is_following(U8* user, U8* actor)
{
    JsonArray* iter_following = db->o("following")->a(user);
    if (!iter_following) {
        return FALSE;
    }
    I64 i;
    for (i = 0; i < iter_following->length; i++) {
        if (!StrICmp(actor, iter_following->@(i))) {
            return TRUE;
        }
    }
    return FALSE;
}
