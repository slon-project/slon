#define ICMP_REQUEST_PTR 0x300020

MemSet(ICMP_REQUEST_PTR, NULL, sizeof(U64));

class IcmpRequest {
    U64 addr;
    U64 iden;
    U64 seq;
    U64 pointer_to_u32;
};

U32 @icmp_echo_request(U32 addr, U16 iden, U16 seq, IcmpRequest* request, I64 count)
{
    U32 res = 0; // low 16 = ttl, hi 16 = payload size
    request->addr = addr;
    request->iden = iden;
    request->seq = seq;
    request->pointer_to_u32 = &res;
    I64 start_jiffies = cnts.jiffies;
    U64* request_ptr = ICMP_REQUEST_PTR;
    if (!count)
        *request_ptr = NULL;
    while (*request_ptr) {
        if (!(cnts.jiffies < start_jiffies + 1000))
            return res;
        Sleep(1);
    }
    LXchgU32(request_ptr, request);
    while (!res && cnts.jiffies < start_jiffies + 1000)
        Sleep(1);
    return res;
}