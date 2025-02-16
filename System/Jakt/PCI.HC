U0 _Z8pci_findl()
{
    // pci_find(long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIClassFind(p0, 0);
    POP_SYSV_REGS
}

U0 _Z11pci_read_u8llll()
{
    // pci_read_u8(long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIReadU8(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U0 _Z12pci_read_u16llll()
{
    // pci_read_u16(long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIReadU16(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U0 _Z12pci_read_u32llll()
{
    // pci_read_u32(long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIReadU32(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U0 _Z12pci_write_u8llllh()
{
    // pci_write_u8(long, long, long, long, unsigned char)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIWriteU8(p0, p1, p2, p3, p4);
    POP_SYSV_REGS
}

U0 _Z13pci_write_u16llllt()
{
    // pci_write_u16(long, long, long, long, unsigned short)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIWriteU16(p0, p1, p2, p3, p4);
    POP_SYSV_REGS
}

U0 _Z13pci_write_u32llllj()
{
    // pci_write_u32(long, long, long, long, unsigned int)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    PCIWriteU32(p0, p1, p2, p3, p4);
    POP_SYSV_REGS
}
