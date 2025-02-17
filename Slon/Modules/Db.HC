#define SLON_MISSING_ACCOUNT_AVATAR "https://slon-project.org/images/avatar-missing.png"

#define SLON_DB_PATH "A:/db"

JsonObject* db = Json.CreateObject();

U0 @slon_db_load_accounts_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/accounts.json", SLON_DB_PATH);
    db->set("accounts", Json.ParseFile(scratch_buffer), JSON_ARRAY);
}

U0 @slon_db_load_actors_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/actors.json", SLON_DB_PATH);
    db->set("actors", Json.ParseFile(scratch_buffer), JSON_OBJECT);
}

U0 @slon_db_load_apps_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/apps.json", SLON_DB_PATH);
    db->set("apps", Json.ParseFile(scratch_buffer), JSON_OBJECT);
}

U0 @slon_db_load_instance_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/instance.json", SLON_DB_PATH);
    db->set("instance", Json.ParseFile(scratch_buffer), JSON_OBJECT);
}

U0 @slon_db_load_oauth_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/oauth.json", SLON_DB_PATH);
    db->set("oauth", Json.ParseFile(scratch_buffer), JSON_OBJECT);
}

U0 @slon_db_load_private_keys_from_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/private_keys.json", SLON_DB_PATH);
    db->set("private_keys", Json.ParseFile(scratch_buffer), JSON_OBJECT);
}

U0 @slon_db_load_followers_from_disk()
{
    JsonObject* followers = Json.CreateObject();
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/followers/*.json", SLON_DB_PATH);
    CDirEntry* files = FilesFind(scratch_buffer);
    CDirEntry* de = files;
    JsonArray* follower_array = NULL;
    while (de) {
        follower_array = Json.ParseFile(de->full_name);
        if (follower_array) {
            StrFind(".json", de->name)[0] = NULL;
            followers->set(de->name, follower_array, JSON_ARRAY);
        }
        de = de->next;
    }
    DirTreeDel(files);
    db->set("followers", followers, JSON_OBJECT);
}

U0 @slon_db_load_following_from_disk()
{
    JsonObject* following = Json.CreateObject();
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/following/*.json", SLON_DB_PATH);
    CDirEntry* files = FilesFind(scratch_buffer);
    CDirEntry* de = files;
    JsonArray* following_array = NULL;
    while (de) {
        following_array = Json.ParseFile(de->full_name);
        if (following_array) {
            StrFind(".json", de->name)[0] = NULL;
            following->set(de->name, following_array, JSON_ARRAY);
        }
        de = de->next;
    }
    DirTreeDel(files);
    db->set("following", following, JSON_OBJECT);
}

U0 @slon_db_load_statuses_from_disk()
{
    JsonObject* statuses = Json.CreateObject();
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/statuses/*.json", SLON_DB_PATH);
    CDirEntry* files = FilesFind(scratch_buffer);
    CDirEntry* de = files;
    JsonArray* status_array = NULL;
    while (de) {
        status_array = Json.ParseFile(de->full_name);
        if (status_array) {
            StrFind(".json", de->name)[0] = NULL;
            statuses->set(de->name, status_array, JSON_ARRAY);
        }
        de = de->next;
    }
    DirTreeDel(files);
    db->set("statuses", statuses, JSON_OBJECT);
}

U0 @slon_db_load_timelines_from_disk()
{
    JsonObject* timelines = Json.CreateObject();

    JsonObject* home_statuses = Json.CreateObject();
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/timelines/home/*.json", SLON_DB_PATH);
    CDirEntry* files = FilesFind(scratch_buffer);
    CDirEntry* de = files;
    JsonArray* status_array = NULL;
    while (de) {
        status_array = Json.ParseFile(de->full_name);
        if (status_array) {
            StrFind(".json", de->name)[0] = NULL;
            home_statuses->set(de->name, status_array, JSON_ARRAY);
        }
        de = de->next;
    }
    DirTreeDel(files);
    timelines->set("home", home_statuses, JSON_OBJECT);

    db->set("timelines", timelines, JSON_OBJECT);
}

U0 @slon_db_save_accounts_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/accounts.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->a("accounts"));
}

U0 @slon_db_save_actors_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/actors.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->o("actors"));
}

U0 @slon_db_save_apps_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/apps.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->o("apps"));
}

U0 @slon_db_save_instance_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/instance.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->o("instance"));
}

U0 @slon_db_save_oauth_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/oauth.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->o("oauth"));
}

U0 @slon_db_save_private_keys_to_disk()
{
    U8 scratch_buffer[256];
    StrPrint(scratch_buffer, "%s/private_keys.json", SLON_DB_PATH);
    Json.DumpToFile(scratch_buffer, db->o("private_keys"));
}

U0 @slon_db_save_followers_to_disk()
{
    U8 scratch_buffer[256];
    JsonKey* key = db->o("followers")->keys;
    while (key) {
        StrPrint(scratch_buffer, "%s/followers/%s.json", SLON_DB_PATH, key->name);
        Json.DumpToFile(scratch_buffer, key->value);
        key = key->next;
    }
}

U0 @slon_db_save_following_to_disk()
{
    U8 scratch_buffer[256];
    JsonKey* key = db->o("following")->keys;
    while (key) {
        StrPrint(scratch_buffer, "%s/following/%s.json", SLON_DB_PATH, key->name);
        Json.DumpToFile(scratch_buffer, key->value);
        key = key->next;
    }
}

U0 @slon_db_save_statuses_to_disk()
{
    U8 scratch_buffer[256];
    JsonKey* key = db->o("statuses")->keys;
    while (key) {
        StrPrint(scratch_buffer, "%s/statuses/%s.json", SLON_DB_PATH, key->name);
        Json.DumpToFile(scratch_buffer, key->value);
        key = key->next;
    }
}

U0 @slon_db_save_timelines_to_disk()
{
    U8 scratch_buffer[256];
    JsonKey* key = db->o("timelines")->o("home")->keys;
    while (key) {
        StrPrint(scratch_buffer, "%s/timelines/home/%s.json", SLON_DB_PATH, key->name);
        Json.DumpToFile(scratch_buffer, key->value);
        key = key->next;
    }
}

U0 @slon_db_save_to_disk()
{
    @slon_db_save_accounts_to_disk();
    @slon_db_save_actors_to_disk();
    @slon_db_save_apps_to_disk();
    @slon_db_save_followers_to_disk();
    @slon_db_save_following_to_disk();
    @slon_db_save_instance_to_disk();
    @slon_db_save_oauth_to_disk();
    @slon_db_save_private_keys_to_disk();
    @slon_db_save_statuses_to_disk();
    @slon_db_save_timelines_to_disk();
}

U0 @slon_db_load_from_defaults()
{
    db->set("accounts", Json.CreateArray(), JSON_ARRAY);
    db->set("actors", Json.CreateObject(), JSON_OBJECT);
    db->set("apps", Json.CreateObject(), JSON_OBJECT);
    db->set("idempotency_keys", Json.CreateObject(), JSON_OBJECT);
    db->set("private_keys", Json.CreateObject(), JSON_OBJECT);
    db->set("private_keys_binary", Json.CreateObject(), JSON_OBJECT);
    db->set("public_keys", Json.CreateObject(), JSON_OBJECT);
    db->set("followers", Json.CreateObject(), JSON_OBJECT);
    db->set("following", Json.CreateObject(), JSON_OBJECT);
    db->set("instance", Json.ParseFile("M:/Slon/Static/defaults/instance.json"), JSON_OBJECT);
    db->set("statuses", Json.CreateObject(), JSON_OBJECT);
    db->set("timelines", Json.CreateObject(), JSON_OBJECT);
    db->o("timelines")->set("home", Json.CreateObject(), JSON_OBJECT);
    JsonObject* oauth = Json.CreateObject();
    oauth->set("codes", Json.CreateObject(), JSON_OBJECT);
    oauth->set("requests", Json.CreateObject(), JSON_OBJECT);
    oauth->set("responses", Json.CreateObject(), JSON_OBJECT);
    oauth->set("tokens", Json.CreateObject(), JSON_OBJECT);
    db->set("oauth", oauth, JSON_OBJECT);
    db->set("setup", FALSE, JSON_BOOLEAN);
}

U0 @slon_db_load_from_disk()
{
    @slon_db_load_accounts_from_disk();
    @slon_db_load_actors_from_disk();
    @slon_db_load_apps_from_disk();
    db->set("idempotency_keys", Json.CreateObject(), JSON_OBJECT);
    @slon_db_load_private_keys_from_disk();
    db->set("private_keys_binary", Json.CreateObject(), JSON_OBJECT);
    db->set("public_keys", Json.CreateObject(), JSON_OBJECT);
    @slon_db_load_followers_from_disk();
    @slon_db_load_following_from_disk();
    @slon_db_load_instance_from_disk();
    @slon_db_load_oauth_from_disk();
    @slon_db_load_statuses_from_disk();
    @slon_db_load_timelines_from_disk();
    db->set("setup", TRUE, JSON_BOOLEAN);
}

U0 @slon_db_instance_update_user_count()
{
    JsonObject* stats = db->o("instance")->o("stats");
    stats->set("user_count", db->a("accounts")->length);
}

U0 @slon_db_instance_decrement_status_count()
{
    JsonObject* stats = db->o("instance")->o("stats");
    stats->set("status_count", MaxI64(0, stats->@("status_count") - 1));
}

U0 @slon_db_instance_increment_status_count()
{
    JsonObject* stats = db->o("instance")->o("stats");
    stats->set("status_count", stats->@("status_count") + 1);
}

U0 @slon_db_actors_update_user(JsonObject* acct)
{
    JsonObject* actors = db->o("actors");
    JsonObject* actor = actors->o(acct->@("username"));

    if (!actor) {
        // FIXME: Handle this error
        return;
    }
    actor->set("name", acct->@("display_name"));
    actor->set("summary", acct->@("note"));
    JsonObject* icon = actor->o("icon");
    icon->set("url", acct->@("avatar"));
    actor->set("attachment", acct->@("fields"));
    @slon_db_save_actors_to_disk;
}

U0 @slon_db_init()
{
    if (FileFind(SLON_DB_PATH)) {
        @slon_log(LOG_DB, "loading db from disk");
        @slon_db_load_from_disk;
    } else {
        @slon_log(LOG_DB, "no db found; loading defaults");
        @slon_db_load_from_defaults;
    }
}

@slon_db_init;

JsonArray* SLON_EMPTY_JSON_ARRAY = Json.CreateArray();
JsonObject* SLON_EMPTY_JSON_OBJECT = Json.CreateObject();

JsonObject* SLON_DEFAULT_ACCT_OBJECT = Json.ParseFile("M:/Slon/Static/defaults/account.json");
JsonObject* SLON_DEFAULT_ACTOR_OBJECT = Json.ParseFile("M:/Slon/Static/defaults/actor.json");
