U0 NetRep()
{
    NetInfoRequest* req = @net_info_request;
    "MAC address       : %02x:%02x:%02x:%02x:%02x:%02x\n", req->mac_address.u8[5], req->mac_address.u8[4],
        req->mac_address.u8[3], req->mac_address.u8[2],
        req->mac_address.u8[1], req->mac_address.u8[0];
    "IPv4 address      : %d.%d.%d.%d\n", req->ipv4_address.u8[3], req->ipv4_address.u8[2],
        req->ipv4_address.u8[1], req->ipv4_address.u8[0];
    "IPv4 netmask      : %d.%d.%d.%d\n", req->ipv4_netmask.u8[3], req->ipv4_netmask.u8[2],
        req->ipv4_netmask.u8[1], req->ipv4_netmask.u8[0];
    "IPv4 network      : %d.%d.%d.%d\n", req->ipv4_network.u8[3], req->ipv4_network.u8[2],
        req->ipv4_network.u8[1], req->ipv4_network.u8[0];
    "IPv4 gateway      : %d.%d.%d.%d\n", req->ipv4_gateway.u8[3], req->ipv4_gateway.u8[2],
        req->ipv4_gateway.u8[1], req->ipv4_gateway.u8[0];
    "DNS server (port) : %d.%d.%d.%d (%d)\n", req->dns_server_address.u8[3], req->dns_server_address.u8[2],
        req->dns_server_address.u8[1], req->dns_server_address.u8[0], req->dns_server_port;
    "RX bytes          : %d\n", req->rx_bytes;
    "RX frames         : %d\n", req->rx_frames;
    "TX bytes          : %d\n", req->tx_bytes;
    "TX frames         : %d\n", req->tx_frames;
    Free(req);
}
