U0 DnsQuery(U8* host)
{
    U32 result = @dns_query(host);
    if (result == U32_MAX) {
        "Error looking up host %s\n", host;
        return;
    }
    "Query for %s: %d.%d.%d.%d\n", host, result.u8[3], result.u8[2], result.u8[1],
        result.u8[0];
}
