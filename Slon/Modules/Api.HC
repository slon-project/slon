#define SLON_API_LOCAL_TIME_OFFSET 3550
#define SLON_AUTH_ACCOUNT_ID U8* account_id = Json.Get(session->auth, "account_id");

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
