#define DNS_REQUEST_PTR 0x300010

MemSet(DNS_REQUEST_PTR, NULL, sizeof(U64));

class DnsRequest {
    U64 host;
    U64 pointer_to_u32;
};

U32 @dns_query(U8* host)
{
    U32 res = 0;
    if (!host)
        return U32_MAX;
    DnsRequest* request = CAlloc(sizeof(DnsRequest), Fs->code_heap);
    request->host = StrNew(host, adam_task);
    request->pointer_to_u32 = &res;
    U64* request_ptr = DNS_REQUEST_PTR;
    while (*request_ptr)
        Sleep(1);
    LXchgU32(request_ptr, request);
    while (!res)
        Sleep(1);
    return res;
}
