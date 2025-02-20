#define SLON_OAUTH_USERINFO_URL "https://app.simplelogin.io/oauth2/userinfo?access_token="

U0 @slon_oauth_well_known(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn request_json;

    StrPrint(scratch_buffer, "{\"issuer\":\"https://%s\",\"authorization_endpoint\":\"https://%s/oauth/authorize\",\"response_types_supported\":[\"code\"],\"app_registration_endpoint\":\"https://%s/api/v1/apps\"}",
        db->o("instance")->@("uri"), db->o("instance")->@("uri"), db->o("instance")->@("uri"));
    @slon_http_set_content_type(session, "application/json; charset=utf-8");
    session->send(scratch_buffer);
}

U0 @slon_oauth_fetch_token(U8* client_id)
{
    if (!client_id || !StrLen(client_id))
        return;

    U8 url_string[256];
    JsonObject* oauth_request = db->o("oauth")->o("requests")->@(client_id);
    if (!oauth_request)
        return;

    U8* access_token = oauth_request->@("access_token");
    if (!access_token) {
        return;
    }

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, adam_task);
    StrPrint(url_string, "%s%s", SLON_OAUTH_USERINFO_URL, access_token);
    @http_response* resp = fetch(url_string, fetch_buffer);

    if (!resp)
        goto oauth_free_and_return;

    if (resp->body.length) {
        // POSIX people think JSON should end with a new line, and the Jakt parser disagrees :^)
        while (resp->body.data[StrLen(resp->body.data) - 1] == '\n')
            resp->body.data[StrLen(resp->body.data) - 1] = NULL;
        JsonObject* response = Json.Parse(resp->body.data);
        db->o("oauth")->o("responses")->set(client_id, response, JSON_OBJECT);
    }
    // FIXME: Free resp

oauth_free_and_return:
    Free(fetch_buffer);
    Free(client_id);
}

U0 @async_slon_oauth_fetch_token(U8* client_id)
{
    Spawn(&@slon_oauth_fetch_token, StrNew(client_id, adam_task), "OauthFetchTokenTask");
}

U8* @slon_oauth_generate_access_token(SlonHttpSession* session)
{
    return @slon_api_generate_random_hex_string(session, 16);
}

U8* @slon_oauth_generate_authorization_code(SlonHttpSession* session)
{
    return @slon_api_generate_random_hex_string(session, 16);
}

U0 @slon_oauth_verify_access_get(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    U8* client_id = request_json->@("client_id");
    U8* redirect_uri = request_json->@("redirect_uri");
    JsonObject* app_object = db->o("apps")->@(client_id);
    // If client_id or redirect_uri are empty, or if client app doesn't exist, Bad Request
    if (!StrLen(client_id) || !StrLen(redirect_uri) || !app_object) {
        session->status(400);
        return;
    }
    U8* client_secret = app_object->@("client_secret");
    JsonObject* userinfo = db->o("oauth")->o("responses")->@(client_id);
    if (userinfo) {
        // If a userinfo with the client_id exists, read the userinfo Object.
        U8* email = userinfo->@("email");
        if (email && StrLen(email)) {
            JsonObject* acct = @slon_api_account_by_email(email);
            if (acct) {

                // If the account exists,
                // create a token that points to the account
                U8* access_token = NULL;
                Bool access_token_exists = TRUE;
                while (access_token_exists) {
                    if (access_token) {
                        @slon_free(session, access_token);
                    }
                    access_token = @slon_oauth_generate_access_token(session);
                    access_token_exists = db->o("oauth")->o("tokens")->@(access_token) > 0;
                }
                I64 created_at = ToF64(CDate2Unix(Now));

                JsonObject* token_object = Json.CreateObject();
                token_object->set("access_token", access_token, JSON_STRING);
                token_object->set("token_type", "Bearer", JSON_STRING);
                token_object->set("scope", "read write follow push", JSON_STRING);
                token_object->set("created_at", created_at, JSON_NUMBER);
                token_object->set("account_id", acct->@("id"), JSON_STRING);
                token_object->set("client_id", client_id, JSON_STRING);
                token_object->set("email", email, JSON_STRING);
                db->o("oauth")->o("tokens")->set(access_token, token_object, JSON_OBJECT);
                // FIXME: We need to commit this to disk eventually? but not immediately

                U8* authorization_code = NULL;
                Bool authorization_code_exists = TRUE;
                while (authorization_code_exists) {
                    if (authorization_code) {
                        @slon_free(session, authorization_code);
                    }
                    authorization_code = @slon_oauth_generate_authorization_code(session);
                    authorization_code_exists = db->o("oauth")->o("codes")->@(authorization_code) > 0;
                }

                JsonObject* code_object = Json.CreateObject();
                code_object->set("access_token", access_token, JSON_STRING);
                code_object->set("token_type", "Bearer", JSON_STRING);
                code_object->set("scope", "read write follow push", JSON_STRING);
                code_object->set("created_at", created_at, JSON_NUMBER);
                code_object->set("account_id", acct->@("id"), JSON_STRING);
                code_object->set("client_id", client_id, JSON_STRING);
                code_object->set("client_secret", client_secret, JSON_STRING);
                code_object->set("email", email, JSON_STRING);
                db->o("oauth")->o("codes")->set(authorization_code, code_object, JSON_OBJECT);
                @slon_db_save_oauth_to_disk;

                StrPrint(scratch_buffer, "%s?code=%s", redirect_uri, authorization_code);
                JsonObject* redirect_uri_object = Json.CreateObject();
                redirect_uri_object->set("redirect_uri", scratch_buffer, JSON_STRING);
                session->send(redirect_uri_object);
                Json.Delete(redirect_uri_object);

                @slon_free(session, authorization_code);
                @slon_free(session, access_token);

            } else {
                // If the account does not exist, return Not Found
                session->status(404);
            }
        } else {
            // Response doesn't contain an email, therefore user is Unauthorized.
            session->status(401);
        }
        return;
    } else {
        if (!db->o("oauth")->o("requests")->@(client_id)) {
            // If a request with the client_id does not exist, create one, and spawn a fetch() instance to retrieve the OAuth2 token.
            db->o("oauth")->o("requests")->set(client_id, request_json, JSON_OBJECT);
            @async_slon_oauth_fetch_token(client_id);
        }
        session->status(202);
    }
    Json.Delete(app_object);
}

U0 @slon_oauth_token_post(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    U8* client_id = request_json->@("client_id");
    U8* client_secret = request_json->@("client_secret");
    U8* code = request_json->@("code");

    JsonObject* code_object = db->o("oauth")->o("codes")->@(code);
    if (!StrLen(client_id) || !StrLen(client_secret) || !code_object) {
        // If client_id is empty, or client_secret is empty, or the code doesn't exist, it's a Bad Request.
        session->status(400);
        return;
    }

    U8* access_token = code_object->@("access_token");
    if (!StrCmp(client_id, code_object->@("client_id")) && !StrCmp(client_secret, code_object->@("client_secret"))) {
        JsonObject* token = db->o("oauth")->o("tokens")->@(access_token);
        if (token) {
            session->send(token);
        } else {
            // If the token doesn't exist, Page Expired?
            session->status(419);
        }
    } else {
        // If client_id and client_secret do not match, it's Unauthorized
        session->status(401);
    }

    Json.Delete(code_object);
}
