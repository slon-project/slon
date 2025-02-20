U8* @slon_api_v1_apps_generate_app_id(SlonHttpSession* session)
{
    U8* app_id = @slon_calloc(session, 16);
    I64 i;
    for (i = 0; i < 6; i++) {
        String.Append(app_id, "%d", RandU64 % 10);
    }
    return app_id;
}

U8* @slon_api_v1_apps_generate_client_id(SlonHttpSession* session)
{
    U8* client_id = NULL;
    Bool client_id_exists = TRUE;
    while (client_id_exists) {
        if (client_id)
            @slon_free(session, client_id);
        client_id = @slon_api_generate_random_hex_string(session, 16);
        client_id_exists = db->o("apps")->@(client_id) > 0;
    }
    return client_id;
}

U8* @slon_api_v1_apps_generate_client_secret(SlonHttpSession* session)
{
    return @slon_api_generate_random_hex_string(session, 32);
}

U0 @slon_api_v1_apps_post(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    U8* id = @slon_api_v1_apps_generate_app_id(session);
    U8* client_id = @slon_api_v1_apps_generate_client_id(session);
    U8* client_secret = @slon_api_v1_apps_generate_client_secret(session);

    I64 request_scopes_count = 0;
    U8** request_scopes = NULL;
    if (StrFind("+", request_json->@("scopes")) > 0) {
        request_scopes = String.Split(request_json->@("scopes"), '+', &request_scopes_count);
    } else {
        request_scopes = String.Split(request_json->@("scopes"), ' ', &request_scopes_count);
    }

    JsonArray* scopes = Json.CreateArray();
    I64 i;
    for (i = 0; i < request_scopes_count; i++) {
        scopes->append(Json.CreateItem(request_scopes[i], JSON_STRING));
    }

    JsonArray* redirect_uris = Json.CreateArray();
    redirect_uris->append(Json.CreateItem(request_json->@("redirect_uris"), JSON_STRING));

    JsonObject* credential_app = Json.CreateObject();
    credential_app->set("id", id, JSON_STRING);
    credential_app->set("name", request_json->@("client_name"), JSON_STRING);
    credential_app->set("website", request_json->@("website"), JSON_STRING);
    credential_app->set("scopes", scopes, JSON_ARRAY);
    credential_app->set("redirect_uris", redirect_uris, JSON_ARRAY);
    credential_app->set("redirect_uri", request_json->@("redirect_uris"), JSON_STRING);
    credential_app->set("client_id", client_id, JSON_STRING);
    credential_app->set("client_secret", client_secret, JSON_STRING);
    credential_app->set("client_secret_expires_at", "0", JSON_STRING);
    db->o("apps")->set(client_id, credential_app, JSON_OBJECT);
    @slon_db_save_apps_to_disk;

    session->send(credential_app);

    @slon_free(session, id);
    @slon_free(session, client_id);
    @slon_free(session, client_secret);
}
