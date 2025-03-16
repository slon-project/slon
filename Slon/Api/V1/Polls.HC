U0 @slon_api_v1_async_vote_fedi(JsonObject* vote_object)
{
    U8 scratch_buffer[512];
    I64 this_vote_id = SysTimerRead;

    JsonArray* choices = vote_object->a("choices");
    JsonObject* status = vote_object->o("status");
    JsonObject* ap_vote_object = NULL;
    JsonObject* object = NULL;
    U8* choice_name = NULL;

    U8* this_actor = db->o("actors")->o(vote_object->@("username"))->@("id");
    U8* remote_actor = status->o("account")->@("remote_actor");

    U8* fetch_buffer = CAlloc(HTTP_FETCH_BUFFER_SIZE, slon_mem_task);

    I64 i;
    for (i = 0; i < choices->length; i++) {
        choice_name = status->o("poll")->a("options")->o(i)->@("title");

        ap_vote_object = Json.CreateObject(slon_mem_task);
        ap_vote_object->set("@context", "https://www.w3.org/ns/activitystreams", JSON_STRING);
        StrPrint(scratch_buffer, "%s#votes/%d/activity", this_actor, this_vote_id);
        ap_vote_object->set("id", scratch_buffer, JSON_STRING);
        ap_vote_object->set("to", remote_actor, JSON_STRING);
        ap_vote_object->set("actor", this_actor, JSON_STRING);
        ap_vote_object->set("type", "Create", JSON_STRING);

        object = Json.CreateObject(slon_mem_task);
        StrPrint(scratch_buffer, "%s#votes/%d", this_actor, this_vote_id);
        object->set("id", scratch_buffer, JSON_STRING);
        object->set("type", "Note", JSON_STRING);
        object->set("name", choice_name, JSON_STRING);
        object->set("attributedTo", this_actor, JSON_STRING);
        object->set("to", remote_actor, JSON_STRING);
        object->set("inReplyTo", status->@("uri"), JSON_STRING);

        ap_vote_object->set("object", object, JSON_OBJECT);
        StrPrint(scratch_buffer, "%s/inbox", remote_actor);
        @slon_activitypub_signed_request(scratch_buffer, fetch_buffer, ap_vote_object);
        MemSet(fetch_buffer, NULL, HTTP_FETCH_BUFFER_SIZE);
    }
    Free(fetch_buffer);
}

U0 @slon_api_v1_vote_fedi(U8* username, JsonObject* status, JsonArray* choices)
{
    JsonObject* vote_object = Json.CreateObject(slon_mem_task);
    vote_object->set("username", username, JSON_STRING);
    vote_object->set("status", status, JSON_OBJECT);
    vote_object->set("choices", choices, JSON_ARRAY);
    Spawn(&@slon_api_v1_async_vote_fedi, vote_object, "SlonAsyncVoteTask");
}

U0 @slon_api_v1_polls_get(SlonHttpSession* session)
{
    if (session->path_count() < 4) {
        session->status(400);
        return;
    }

    U8* id = session->path(3);
    JsonObject* status = NULL;
    JsonObject* poll = NULL;
    JsonArray* poll_choices = NULL;
    JsonItem* poll_choice = NULL;
    JsonArray* own_votes = NULL;

    U8* account_id = NULL;
    if (session->auth) {
        account_id = session->auth->@("account_id");
    }

    I64 i;
    if (@slon_api_authorized(session)) {
        status = @slon_api_find_status_by_poll_id(id, NULL);
        if (status) {
            poll = Json.Clone(status->o("poll"), session->mem_task);
            poll_choices = @slon_api_status_poll_choices(session, status, account_id);
            own_votes = Json.CreateArray(session->mem_task);
            for (i = 0; i < poll_choices->length; i++) {
                poll_choice = poll_choices->@(i, TRUE);
                switch (poll_choice->type) {
                case JSON_NUMBER:
                    own_votes->append(poll_choice->value, JSON_NUMBER);
                    break;
                case JSON_STRING:
                    own_votes->append(Str2I64(poll_choice->value), JSON_NUMBER);
                    break;
                default:
                    break;
                }
            }
            poll->set("voted", poll_choices > NULL, JSON_BOOLEAN);
            poll->set("own_votes", own_votes, JSON_ARRAY);
            session->send(poll);
            return;
        }
        session->status(404);
    } else {
        session->status(401);
    }
}

U0 @slon_api_v1_polls_post(SlonHttpSession* session)
{
    SLON_SCRATCH_BUFFER_AND_REQUEST_JSON
    no_warn scratch_buffer;

    if (session->path_count() < 5) {
        session->status(400);
        return;
    }

    U8* id = session->path(3);

    JsonObject* status = NULL;
    JsonObject* poll = NULL;
    JsonObject* return_poll = NULL;

    JsonArray* choices = NULL;
    JsonArray* options = NULL;
    JsonItem* choice = NULL;
    JsonObject* option = NULL;
    JsonArray* own_votes = NULL;

    JsonObject* vote = NULL;

    // Still won't let us vote: iOS Masto

    if (@slon_api_authorized(session)) {
        SLON_AUTH_ACCOUNT_ID

        status = @slon_api_find_status_by_poll_id(id, NULL);
        if (!status) {
            session->status(404);
            return;
        }

        I64 i;
        I64 choice_index = 0;
        poll = status->o("poll");
        choices = request_json->@("choices");
        options = poll->a("options");
        own_votes = Json.CreateArray(session->mem_task);

        for (i = 0; i < choices->length; i++) {
            choice = choices->@(i, TRUE);
            switch (choice->type) {
            case JSON_STRING:
                choice_index = Str2I64(choice->value);
                break;
            case JSON_NUMBER:
                choice_index = choice->value;
                break;
            default:
                break;
            }
            own_votes->append(choice_index, JSON_NUMBER);
            option = options->o(choice_index);
            option->set("votes_count", option->@("votes_count") + 1, JSON_NUMBER);
            poll->set("votes_count", poll->@("votes_count") + 1, JSON_NUMBER);
        }

        @slon_db_save_status_to_disk(status);

        vote = Json.CreateObject(slon_db_mem_task);
        vote->set("status_id", status->@("id"), JSON_STRING);
        vote->set("account_id", account_id, JSON_STRING);
        vote->set("choices", Json.Clone(choices, slon_db_mem_task), JSON_ARRAY);

        if (!db->o("votes")->a(account_id)) {
            db->o("votes")->set(account_id, Json.CreateArray(slon_db_mem_task), JSON_ARRAY);
        }
        db->o("votes")->a(account_id)->append(vote);
        @slon_db_save_votes_to_disk;

        return_poll = Json.Clone(poll, session->mem_task);
        return_poll->set("voted", TRUE, JSON_BOOLEAN);
        return_poll->set("own_votes", own_votes, JSON_ARRAY);

        // Multiple-choice votes have to be sent in separate requests for each option? wtf
        if (status->o("account")->@("remote_actor")) {
            // Send votes asynchronously
            @slon_api_v1_vote_fedi(@slon_api_account_by_id(account_id)->@("acct"), status, vote->a("choices"));
        }
        session->send(return_poll);
    } else {
        session->status(401);
    }
}
