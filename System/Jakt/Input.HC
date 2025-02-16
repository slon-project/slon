U0 _Z16input_get_stringPKc()
{
    // input_get_string(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GetStr(p0);
    POP_SYSV_REGS
}

Bool @input_key_down(U8 scancode) { return Bt(kbd.down_bitmap, scancode); }

U0 _Z14input_key_downh()
{
    // input_key_down(unsigned char)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @input_key_down(p0);
    POP_SYSV_REGS
}

Bool @input_mouse_left() { return ms.lb; }

U0 _Z16input_mouse_leftv()
{
    // input_mouse_left()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @input_mouse_left();
    POP_SYSV_REGS
}

Bool @input_mouse_right() { return ms.rb; }

U0 _Z17input_mouse_rightv()
{
    // input_mouse_right()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @input_mouse_right();
    POP_SYSV_REGS
}

I64 @input_mouse_x() { return ms.pos.x; }

U0 _Z13input_mouse_xv()
{
    // input_mouse_x()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @input_mouse_x();
    POP_SYSV_REGS
}

I64 @input_mouse_y() { return ms.pos.y; }

U0 _Z13input_mouse_yv()
{
    // input_mouse_y()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @input_mouse_y();
    POP_SYSV_REGS
}

U0 _Z17input_press_a_keyv()
{
    // input_press_a_key()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PressAKey;
    POP_SYSV_REGS
}