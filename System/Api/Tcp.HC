#define TCP_SOCKET_REQUEST_PTR 0x300000
#define TCP_BIND_REQUEST_PTR 0x300040
#define TCP_ACCEPT_REQUEST_PTR 0x300050

MemSet(TCP_SOCKET_REQUEST_PTR, NULL, sizeof(U64));

// TcpSocket states

#define TCP_SOCKET_STATE_IDLE 0
#define TCP_SOCKET_STATE_ESTABLISHED 1
#define TCP_SOCKET_STATE_CLOSED 2
#define TCP_SOCKET_STATE_CONNECTING 4

class TcpSocket {
    U64 remote_addr;
    U64 remote_port;
    U64 state;
    U64 receive_buffer_ptr; // Pointer to receive buffer in physical memory
    U64 receive_buffer_size;
    U64 receive_buffer_filled; // Number of bytes Net has put into buffer
    U64 receive_buffer_kick;   // Net sets this to 1 when it has data available for
                               // us, we set back to 0 when ready to receive
    U64 send_buffer_ptr;
    U64 send_buffer_size;
    U64 send_buffer_filled;
    U64 send_buffer_kick; // We set this to 1 when we have data available to net,
                          // Net sets back to 0 when ready to receive
    U0(*close)
    ();
    U64(*receive)
    (U64 buf, U64 length);
    U0(*send)
    (U64 buf, U64 length);
};

class TcpBind {
    U64 port;
    U64 function;
    U64 response_code;
};

U8 @tcp_close_wrapper_function[16]
    = { 0x55, 0x48, 0x8B, 0xEC, 0x68, 0x78,
          0x56, 0x34, 0x12, 0xE8, 0x02, 0x6D,
          0x02, 0x00, 0x5D, 0xC3 };

U8 @tcp_receive_wrapper_function[32] = {
    0x55, 0x48, 0x8B, 0xEC, 0x56, 0x57, 0x48, 0x8B, 0x75, 0x18, 0x48,
    0x8B, 0x7D, 0x10, 0x56, 0x57, 0x68, 0x78, 0x56, 0x34, 0x12, 0xE8,
    0x5E, 0x62, 0x02, 0x00, 0x5F, 0x5E, 0x5D, 0xC2, 0x10, 0x00
};

U8 @tcp_send_wrapper_function[32] = {
    0x55, 0x48, 0x8B, 0xEC, 0x56, 0x57, 0x48, 0x8B, 0x75, 0x18, 0x48,
    0x8B, 0x7D, 0x10, 0x56, 0x57, 0x68, 0x78, 0x56, 0x34, 0x12, 0xE8,
    0x5E, 0x62, 0x02, 0x00, 0x5F, 0x5E, 0x5D, 0xC2, 0x10, 0x00
};

U0 @tcp_socket_send(TcpSocket* s, U64 buf, U64 length)
{
    while (s->send_buffer_kick)
        Sleep(1);
    U64 pos = 0;
    U64 bytes_to_send = 0;
    while (pos < length) {
        if ((length - pos) > s->send_buffer_size)
            bytes_to_send = s->send_buffer_size;
        else
            bytes_to_send = length - pos;
        MemCpy(s->send_buffer_ptr, buf + pos, bytes_to_send);
        s->send_buffer_filled = bytes_to_send;
        s->send_buffer_kick = 1;
        pos += bytes_to_send;
        while (s->send_buffer_kick)
            Sleep(1);
    }
}

U64 @tcp_socket_receive(TcpSocket* s, U64 buf, U64 size)
{
    s->receive_buffer_size = size;
    s->receive_buffer_kick = 0;
    while (!s->receive_buffer_kick) {
        if (s->state == TCP_SOCKET_STATE_CLOSED)
            return NULL;
        Sleep(1);
    }
    U64 bytes_received = s->receive_buffer_filled;
    if (bytes_received > 0) {
        MemCpy(buf, s->receive_buffer_ptr, bytes_received);
    }
    return bytes_received;
}

U0 @tcp_wait_for_connection_established(TcpSocket* s)
{
    while (s->state != TCP_SOCKET_STATE_ESTABLISHED)
        Sleep(1);
}

U0 @tcp_socket_close(TcpSocket* s)
{
    if (s->close)
        Free(s->close);
    if (s->receive)
        Free(s->receive);
    if (s->send)
        Free(s->send);
    s->state = TCP_SOCKET_STATE_CLOSED;
}

TcpSocket* @tcp_socket_create(U8* host, U64 port)
{
    U64 addr = @dns_query(host);
    TcpSocket* s = CAlloc(sizeof(TcpSocket), adam_task->code_heap);
    s->remote_addr = addr;
    s->remote_port = port;

    U64 a;

    s->close = MAlloc(16, adam_task->code_heap);
    MemCpy(s->close, @tcp_close_wrapper_function, 16);
    a = s->close;
    a += 0x05;
    MemSetU32(a, s, 1);
    a = s->close;
    a += 0x09;
    @patch_call_rel32(a, &@tcp_socket_close);

    s->receive = MAlloc(25, adam_task->code_heap);
    MemCpy(s->receive, @tcp_receive_wrapper_function, 32);
    a = s->receive;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->receive;
    a += 0x15;
    @patch_call_rel32(a, &@tcp_socket_receive);

    s->send = MAlloc(32, adam_task->code_heap);
    MemCpy(s->send, @tcp_send_wrapper_function, 32);
    a = s->send;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->send;
    a += 0x15;
    @patch_call_rel32(a, &@tcp_socket_send);

    U64* request_ptr = TCP_SOCKET_REQUEST_PTR;
    while (*request_ptr)
        Sleep(1);
    LXchgU32(request_ptr, s);
    return s;
}

U64 @tcp_socket_bind(U64 port, U64 function)
{
    if (!port || !function)
        return NULL;

    TcpBind* b = CAlloc(sizeof(TcpBind), adam_task->code_heap);
    b->port = port;
    b->function = function; // U0 my_spawn_wrapper_function(TcpSocket* s)

    U64* request_ptr = TCP_BIND_REQUEST_PTR;
    while (*request_ptr)
        Sleep(1);
    LXchgU32(request_ptr, b);
    while (*request_ptr)
        Sleep(1);
    U64 res = b->response_code;
    Free(b);
    return res;
}

TcpSocket* @tcp_socket_accept(TcpSocket* s)
{
    if (!s || !s->remote_addr || !s->remote_port)
        return NULL;

    U64 a;

    s->close = MAlloc(16, adam_task->code_heap);
    MemCpy(s->close, @tcp_close_wrapper_function, 16);
    a = s->close;
    a += 0x05;
    MemSetU32(a, s, 1);
    a = s->close;
    a += 0x09;
    @patch_call_rel32(a, &@tcp_socket_close);

    s->receive = MAlloc(25, adam_task->code_heap);
    MemCpy(s->receive, @tcp_receive_wrapper_function, 32);
    a = s->receive;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->receive;
    a += 0x15;
    @patch_call_rel32(a, &@tcp_socket_receive);

    s->send = MAlloc(32, adam_task->code_heap);
    MemCpy(s->send, @tcp_send_wrapper_function, 32);
    a = s->send;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->send;
    a += 0x15;
    @patch_call_rel32(a, &@tcp_socket_send);

    return s;
}
