U32 @ipv4_address(I64 o3, I64 o2, I64 o1, I64 o0)
{
    U32 addr = NULL;
    addr.u8[3] = o3;
    addr.u8[2] = o2;
    addr.u8[1] = o1;
    addr.u8[0] = o0;
    return addr;
}
