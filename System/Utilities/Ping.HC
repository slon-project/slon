#define PING_ERR_INVALID_HOST 1
#define PING_ERR_HOST_NOT_FOUND 2

#define PING_PAYLOAD_SIZE 56

I64 @ping_err(I64 code)
{
    switch (code) {
    case PING_ERR_INVALID_HOST:
        "Invalid host specified\n";
        return 1;
        break;
    case PING_ERR_HOST_NOT_FOUND:
        "Host not found\n";
        return 2;
        break;
    default:
        "Unspecified error\n";
        return -1;
    }
}

I64 Ping(U8* host, I64 count = 4)
{
    if (!host)
        return @ping_err(PING_ERR_INVALID_HOST);
    if (!StrLen(host))
        return @ping_err(PING_ERR_INVALID_HOST);

    U32 addr = @dns_query(host);
    if (addr == U32_MAX)
        return @ping_err(PING_ERR_HOST_NOT_FOUND);

    U16 iden = (RandU16 * SysTimerRead) & 0xFFFF;
    I64 start_jiffies;
    U32 reply = NULL;
    I64 res = 0;
    U16 seq = 0;
    I64 loss = 0;

    IcmpRequest* request = CAlloc(sizeof(IcmpRequest), Fs->code_heap);

    "PING %s (%d.%d.%d.%d): %d data bytes\n",
        host, addr.u8[3], addr.u8[2], addr.u8[1], addr.u8[0], PING_PAYLOAD_SIZE;

    I64 i;
    for (i = 0; i < count; i++) {
        start_jiffies = cnts.jiffies;
        reply = @icmp_echo_request(addr, iden, seq, request, i);
        if (!reply) {
            "Request timeout for icmp_seq %d\n", seq;
            ++loss;
            res = 1;
        } else {
            "%d bytes from %d.%d.%d.%d: icmp_seq=%d ttl=%d time=%d ms\n",
                reply.u16[1], addr.u8[3], addr.u8[2], addr.u8[1], addr.u8[0], seq, reply.u16[0], cnts.jiffies - start_jiffies;
        }
        while (cnts.jiffies < start_jiffies + 1000 && i < (count - 1))
            Sleep(1);
        ++seq;
    }

    Free(request);

    "--- %d.%d.%d.%d ping statistics ---\n", addr.u8[3], addr.u8[2], addr.u8[1], addr.u8[0];
    "%d packets transmitted, %d packets received, %0f",
        seq, seq - loss, (loss * 1.0 / seq * 1.0) * 100;
    PutChars(37);
    " packet loss\n";

    return res;
}