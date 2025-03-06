#define TLS_CONNECT_TASK_STACK_SIZE 524288
#define TLS_CLIENT_MESSAGE_BUFFER_SIZE 0xFFFF

class TlsSocket : TcpSocket {
    U64 ctx;
    U8 client_message[TLS_CLIENT_MESSAGE_BUFFER_SIZE];
};

U0 @tls_send_pending(TlsSocket* s)
{
    U32 out_buffer_len = 0;
    U8* out_buffer = @tls_get_write_buffer(s->ctx, &out_buffer_len);
    if (out_buffer && out_buffer_len) {
        @tcp_socket_send(s, out_buffer, out_buffer_len);
        @tls_buffer_clear(s->ctx);
    }
}

U0 @tls_socket_send(TlsSocket* s, U64 buf, U64 size)
{
    @tls_write(s->ctx, buf, size);
    @tls_send_pending(s);
}

U64 @tls_socket_receive(TlsSocket* s, U8* buf, I64 size)
{
    I64 len = @tcp_socket_receive(s, s->client_message, TLS_CLIENT_MESSAGE_BUFFER_SIZE);
    if (len) {
        @tls_consume_stream(s->ctx, s->client_message, len, NULL);
        @tls_send_pending(s);
    }
    return @tls_read(s->ctx, buf, size);
}

U0 @tls12_connect(TlsSocket* s)
{
    I64 len;
    @tls_client_connect(s->ctx);
    @tls_send_pending(s);
    while (!@tls_established(s->ctx)) {
        len = @tcp_socket_receive(s, &s->client_message, TLS_CLIENT_MESSAGE_BUFFER_SIZE);
        if (len) {
            @tls_consume_stream(s->ctx, &s->client_message, len, NULL);
            @tls_send_pending(s);
        }
        Sleep(1);
    }
}

TlsSocket* @tls_socket_create(U8* server_name, U64 port = 443)
{
    U64 addr = @dns_query(server_name);
    TlsSocket* s = CAlloc(sizeof(TlsSocket), slon_mem_task->code_heap);
    s->remote_addr = addr;
    s->remote_port = port;

    U64 a;

    s->close = MAlloc(16, slon_mem_task->code_heap);
    MemCpy(s->close, @tcp_close_wrapper_function, 16);
    a = s->close;
    a += 0x05;
    MemSetU32(a, s, 1);
    a = s->close;
    a += 0x09;
    @patch_call_rel32(a, &@tcp_socket_close);

    s->receive = MAlloc(25, slon_mem_task->code_heap);
    MemCpy(s->receive, @tcp_receive_wrapper_function, 32);
    a = s->receive;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->receive;
    a += 0x15;
    @patch_call_rel32(a, &@tls_socket_receive);

    s->send = MAlloc(32, slon_mem_task->code_heap);
    MemCpy(s->send, @tcp_send_wrapper_function, 32);
    a = s->send;
    a += 0x11;
    MemSetU32(a, s, 1);
    a = s->send;
    a += 0x15;
    @patch_call_rel32(a, &@tls_socket_send);

    U64* request_ptr = TCP_SOCKET_REQUEST_PTR;
    while (*request_ptr)
        Sleep(1);
    LXchgU32(request_ptr, s);

    while (s->state != TCP_SOCKET_STATE_ESTABLISHED)
        Sleep(1);

    s->ctx = @tls_create_context(0, TLS_V12);
    @tls_sni_set(s->ctx, StrNew(server_name, slon_mem_task->code_heap));
    Spawn(&@tls12_connect, s, , , , TLS_CONNECT_TASK_STACK_SIZE);

    return s;
}
