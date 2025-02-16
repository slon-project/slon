U0 _Z9time_busyl()
{
    // time_busy(long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Busy(p0);
    POP_SYSV_REGS
}

I64 @time_jiffies() { return cnts.jiffies; }

U0 _Z12time_jiffiesv()
{
    // time_jiffies()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @time_jiffies;
    POP_SYSV_REGS
}

U0 _Z8time_nowv()
{
    // time_now()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Now;
    POP_SYSV_REGS
}

U0 _Z10time_sleepl()
{
    // time_sleep(long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Sleep(p0);
    POP_SYSV_REGS
}