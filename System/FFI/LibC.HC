#define stdin 0
#define stdout 1
#define stderr 2

U0 bcmp()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MemCmp(p0, p1, p2);
    POP_SYSV_REGS
}

U0 calloc()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    CAlloc(p0 * p1, slon_mem_task->code_heap);
    POP_SYSV_REGS
}

U0 free()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    Free(p0);
    POP_SYSV_REGS
}

I64 @isatty()
{
    return 0;
}

U0 isatty()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    // Dbg;
    @isatty;
    POP_SYSV_REGS
}

I64 @fwrite(U8* ptr, I64 size, I64 nmemb, U64 stream)
{
    U8* tmp;
    switch (stream) {
    case stdout:
    case stderr:
        tmp = CAlloc((size * nmemb) + 1, slon_mem_task->code_heap);
        MemCpy(tmp, ptr, (size * nmemb));
#ifdef QEMU_RUN_TESTS
        QemuDebugMsg(tmp);
#endif
        DocPutS(adam_task->put_doc, tmp);
        Free(tmp);
        //        if (!MemCmp(tmp, "VERIFICATION FAILED", 19))
        //            Break;
        break;
    default:
        break;
    }
    return size * nmemb;
}

U0 fwrite()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @fwrite(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U64 @getentropy(U8* buffer, U64 length)
{
    I64 i;
    for (i = 0; i < length; i++)
        buffer[i] = RandU64;
    return 0;
}

U0 getentropy()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @getentropy(p0, p1);
    POP_SYSV_REGS
}

U0 htonl()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    EndianU32(p0);
    POP_SYSV_REGS
}

U0 ntohl()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    EndianU32(p0);
    POP_SYSV_REGS
}

U0 htons()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    EndianU16(p0);
    POP_SYSV_REGS
}

U0 ntohs()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    EndianU16(p0);
    POP_SYSV_REGS
}

U0 malloc()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MAlloc(p0, slon_mem_task->code_heap);
    POP_SYSV_REGS
}

U0 memcmp()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MemCmp(p0, p1, p2);
    POP_SYSV_REGS
}

U0 memcpy()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MemCpy(p0, p1, p2);
    POP_SYSV_REGS
}

U8* @memmove(U8* dest, U8* src, I64 n)
{
    I64 i;
    U8* from = src;
    U8* to = dest;
    if (from == to || n == 0)
        return dest;
    if (to > from && to - from < n) {
        /* to overlaps with from */
        /*  <from......>         */
        /*         <to........>  */
        /* copy in reverse, to avoid overwriting from */
        for (i = n - 1; i >= 0; i--)
            to[i] = from[i];
        return dest;
    }
    if (from > to && from - to < n) {
        /* to overlaps with from */
        /*        <from......>   */
        /*  <to........>         */
        /* copy forwards, to avoid overwriting from */
        for (i = 0; i < n; i++)
            to[i] = from[i];
        return dest;
    }
    MemCpy(dest, src, n);
    return dest;
}

U0 memmove()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @memmove(p0, p1, p2);
    POP_SYSV_REGS
}

U0 memset()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    MemSet(p0, p1, p2);
    POP_SYSV_REGS
}

U0 putc()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PutChars(p0);
    POP_SYSV_REGS
}

U0 rand()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    RandU64;
    POP_SYSV_REGS
}

U8* @realloc(U8* ptr, I64 size)
{
    U8* new;
    if (!ptr) {
        new = MAlloc(size, slon_mem_task->code_heap);
    } else {
        new = MAlloc(size, slon_mem_task->code_heap);
        MemCpy(new, ptr, size);
        Free(ptr);
    }
    return new;
}

U0 realloc()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @realloc(p0, p1);
    POP_SYSV_REGS
}

// FIXME: It is non-obvious how to take a [u8] and convert it to a
//        formatted string in Jakt, so we have to do this hack for
//        now. Hopefully, this will change soon.
U0 sprintf()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    StrPrint(p0, p1, p2, p3, p4, p5);
    POP_SYSV_REGS
}

I64 @strncmp(U8* s1, U8* s2, I32 n)
{
    U64 u1, u2;

    while (n-- > 0) {
        u1 = *s1++;
        u2 = *s2++;
        u1 = u1 & 0xff;
        u2 = u2 & 0xff;
        if (u1 != u2)
            return u1 - u2;
        if (u1 == '\0')
            return 0;
    }
    return 0;
}

U0 strncmp()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @strncmp(p0, p1, p2);
    POP_SYSV_REGS
}

U0 strcmp()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    StrCmp(p0, p1);
    POP_SYSV_REGS
}

U0 strlen()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    StrLen(p0);
    POP_SYSV_REGS
}

I64 tos_nist_offset = 5020;
#define NIST_TIME_OFFSET (tos_nist_offset - local_time_offset / CDATE_FREQ)

public
I64 CDate2Unix(CDate dt)
{ // TempleOS datetime to Unix timestamp.
    return ToI64((dt - Str2Date("1/1/1970")) / CDATE_FREQ + NIST_TIME_OFFSET);
}

I64 @time(I64* ptr)
{
    no_warn ptr;
    return CDate2Unix(Now);
}

U0 time()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @time(p0);
    POP_SYSV_REGS
}

U0 toupper()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    ToUpper(p0);
    POP_SYSV_REGS
}

U0 __assert_fail()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    "%s:%d: %s: %s\n", p1, p2, p3, p0;
    Break;
    POP_SYSV_REGS
}
