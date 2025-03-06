U0 _ZdlPv()
{
    // operator delete(void*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Free(p0);
    POP_SYSV_REGS
}

U0 _ZdlPvm()
{
    // operator delete(void*, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Free(p0);
    POP_SYSV_REGS
}

U0 _Znwm()
{
    // operator new(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MAlloc(p0, slon_mem_task);
    POP_SYSV_REGS
}

U0 _ZnwmRKSt9nothrow_t()
{
    // operator new(unsigned long, std::nothrow_t const&)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MAlloc(p0, slon_mem_task);
    POP_SYSV_REGS
}
