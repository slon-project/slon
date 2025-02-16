#define NETINFO_REQUEST_PTR 0x300030

MemSet(NETINFO_REQUEST_PTR, NULL, sizeof(U64));

class NetInfoRequest {
    U64 mac_address;
    U64 ipv4_address;
    U64 ipv4_netmask;
    U64 ipv4_network;
    U64 ipv4_gateway;
    U64 dns_server_address;
    U64 dns_server_port;
    U64 rx_bytes;
    U64 rx_frames;
    U64 tx_bytes;
    U64 tx_frames;
    U64 pointer_to_u32;
};

NetInfoRequest* @net_info_request()
{
    U32 res = 0;
    NetInfoRequest* req = CAlloc(sizeof(NetInfoRequest), Fs->code_heap);
    req->pointer_to_u32 = &res;
    U64* request_ptr = NETINFO_REQUEST_PTR;
    while (*request_ptr)
        Sleep(1);
    LXchgU32(request_ptr, req);
    while (!res)
        Sleep(1);
    return req;
}
