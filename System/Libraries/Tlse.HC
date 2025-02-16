#define TLS_V12 0x0303

Silent(1); // This is needed to suppress "Function should return val" warnings for wrappers to non-HolyC functions

U64 @tls_create_context(U8 is_server, U16 version)
{
    U64 reg RDI rdi = is_server;
    U64 reg RSI rsi = version;
    no_warn rdi, rsi;
    asm {
        MOV RAX, TLS_CREATE_CONTEXT
        CALL RAX
    }
}

I32 @tls_sni_set(U64 context, U8* sni)
{
    U64 reg RDI rdi = context;
    U64 reg RSI rsi = sni;
    no_warn rdi, rsi;
    asm {
        MOV RAX, TLS_SNI_SET
        CALL RAX
    }
}

I32 @tls_client_connect(U64 context)
{
    U64 reg RDI rdi = context;
    no_warn rdi;
    asm {
        MOV RAX, TLS_CLIENT_CONNECT
        CALL RAX
    }
}

U8* @tls_get_write_buffer(U64 context, U32* outlen)
{
    U64 reg RDI rdi = context;
    U64 reg RSI rsi = outlen;
    no_warn rdi, rsi;
    asm {
        MOV RAX, TLS_GET_WRITE_BUFFER
        CALL RAX
    }
}

U0 @tls_buffer_clear(U64 context)
{
    U64 reg RDI rdi = context;
    no_warn rdi;
    asm {
        MOV RAX, TLS_BUFFER_CLEAR
        CALL RAX
    }
}

I32 @tls_connection_status(U64 context)
{
    U64 reg RDI rdi = context;
    no_warn rdi;
    asm {
        MOV RAX, TLS_CONNECTION_STATUS
        CALL RAX
    }
}

U0 @tls_consume_stream(U64 context, U8* buf, I32 buf_len, U64 certificate_verify)
{
    U64 reg RDI rdi = context;
    U64 reg RSI rsi = buf;
    U64 reg RDX rdx = buf_len;
    U64 reg RCX rcx = certificate_verify;
    no_warn rdi, rsi, rdx, rcx;
    asm {
        MOV RAX, TLS_CONSUME_STREAM
        CALL RAX
    }
}

I32 @tls_read(U64 context, U8* buf, U32 size)
{
    U64 reg RDI rdi = context;
    U64 reg RSI rsi = buf;
    U64 reg RDX rdx = size;
    no_warn rdi, rsi, rdx;
    asm {
        MOV RAX, TLS_READ
        CALL RAX
    }
}

I32 @tls_write(U64 context, U8* data, U32 len)
{
    U64 reg RDI rdi = context;
    U64 reg RSI rsi = data;
    U64 reg RDX rdx = len;
    no_warn rdi, rsi, rdx;
    asm {
        MOV RAX, TLS_WRITE
        CALL RAX
    }
}

I32 @tls_established(U64 context)
{
    U64 reg RDI rdi = context;
    no_warn rdi;
    asm {
        MOV RAX, TLS_ESTABLISHED
        CALL RAX
    }
}

Silent(0);
