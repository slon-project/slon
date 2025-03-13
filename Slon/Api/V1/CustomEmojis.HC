U0 @slon_api_v1_custom_emojis_get(SlonHttpSession* session)
{
    session->send(db->a("custom_emojis"));
}
