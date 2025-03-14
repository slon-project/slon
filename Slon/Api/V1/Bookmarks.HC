U0 @slon_api_v1_bookmarks_get(SlonHttpSession* session)
{
    // SLON_SCRATCH_BUFFER_AND_REQUEST_JSON

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        JsonArray* bookmarks_array = db->o("bookmarks")->a(account_id);
        JsonArray* bookmarks = NULL;
        JsonObject* status = NULL;
        U8* status_acct_id = NULL;
        U8* status_id = NULL;

        I64 i;
        if (bookmarks_array) {
            bookmarks = Json.CreateArray(session->mem_task);
            for (i = 0; i < bookmarks_array->length; i++) {
                status_acct_id = bookmarks_array->o(i)->@("account_id");
                status_id = bookmarks_array->o(i)->@("status_id");
                if (status_id && status_acct_id) {
                    status = @slon_api_find_status_by_id(status_id, status_acct_id);
                    if (status) {
                        status = Json.Clone(status, session->mem_task);
                        // FIXME: We should have a unified way to apply these for an auth user during a query:
                        // favourited, reblogged, muted, bookmarked, pinned, filtered
                        status->set("bookmarked", TRUE, JSON_BOOLEAN);
                        bookmarks->append(status);
                    }
                }
            }
            session->send(bookmarks);
        } else {
            session->send(SLON_EMPTY_JSON_ARRAY);
        }

    } else {
        session->status(401);
    }
}
