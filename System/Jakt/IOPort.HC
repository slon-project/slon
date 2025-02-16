U0 _Z14ioport_read_u8t()
{
    // ioport_read_u8(unsigned short)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    InU8(p0);
    POP_SYSV_REGS
}

U0 _Z15ioport_read_u16t()
{
    // ioport_read_u16(unsigned short)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    InU16(p0);
    POP_SYSV_REGS
}

U0 _Z15ioport_read_u32t()
{
    // ioport_read_u32(unsigned short)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    InU32(p0);
    POP_SYSV_REGS
}

U0 _Z15ioport_write_u8th()
{
    // ioport_write_u8(unsigned short, unsigned char)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    OutU8(p0, p1);
    POP_SYSV_REGS
}

U0 _Z16ioport_write_u16tt()
{
    // ioport_write_u16(unsigned short, unsigned short)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    OutU16(p0, p1);
    POP_SYSV_REGS
}

U0 _Z16ioport_write_u32tj()
{
    // ioport_write_u32(unsigned short, unsigned int)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    OutU32(p0, p1);
    POP_SYSV_REGS
}
