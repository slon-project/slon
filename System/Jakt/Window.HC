U0 @window_draw_it(CTask* task, CDC* dc)
{
    if (task->user_data)
        @dc_copy(dc, task->pix_left, task->pix_top, task->user_data);
}

CTask* @window_user()
{
    CTask* task = Spawn(&UserCmdLine, , , 0);
    TaskWait(task);
    XTalk(task,
        "while (1) { StrCpy(Fs->task_title, Fs->task_name); Sleep(1); };\n");
    return task;
}

CTask* @window_create()
{
    CTask* task = @window_user;
    task->draw_it = &@window_draw_it;
    return task;
}

U0 _Z13window_createv()
{
    // window_create()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @window_create();
    POP_SYSV_REGS
}

U0 _Z14window_destroym()
{
    // window_destroy(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Kill(p0);
    POP_SYSV_REGS
}

Bool @window_is_focused(CTask* task) { return task == sys_focus_task; }

U0 _Z17window_is_focusedm()
{
    // window_is_focused(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @window_is_focused(p0);
    POP_SYSV_REGS
}

U0 @window_set_coordinates(CTask* task, I64 top, I64 left, I64 bottom,
    I64 right)
{
    task->win_top = top;
    task->win_left = left;
    task->win_bottom = bottom;
    task->win_right = right;
}

U0 _Z22window_set_coordinatesmllll()
{
    // window_set_coordinates(unsigned long, long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @window_set_coordinates(p0, p1, p2, p3, p4);
    POP_SYSV_REGS
}

U0 @window_set_context(CTask* task, CDC* dc) { task->user_data = dc; }

U0 _Z18window_set_contextmm()
{
    // window_set_context(unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @window_set_context(p0, p1);
    POP_SYSV_REGS
}

U0 @window_set_title(CTask* task, U8* title)
{
    StrCpy(task->task_name, title);
    StrCpy(task->task_title, title);
}

U0 _Z16window_set_titlemPKc()
{
    // window_set_title(unsigned long, char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @window_set_title(p0, p1);
    POP_SYSV_REGS
}
