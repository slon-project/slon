Silent(1); // This is needed to suppress "Function should return val" warnings for wrappers to non-HolyC functions

I64 @rsa_import(U8* der_bytes, I64 der_len, U64 key)
{
    U64 reg RDI rdi = der_bytes;
    U64 reg RSI rsi = der_len;
    U64 reg RDX rdx = key;
    no_warn rdi, rsi, rdx;
    asm {
        MOV RAX, RSA_IMPORT
        CALL RAX
    }
}

I64 @rsa_create_signature(U8* sig, I64* siglen, U8* hash, I64 hashlen, U64 key)
{
    U64 reg RDI rdi = sig;
    U64 reg RSI rsi = siglen;
    U64 reg RDX rdx = hash;
    U64 reg RCX rcx = hashlen;
    U64 reg R8 r8 = key;
    no_warn rdi, rsi, rdx, rcx, r8;
    asm {
        MOV RAX, RSA_CREATE_SIGNATURE
        CALL RAX
    }
}

I64 @rsa_verify_signature(U8* sig, I64 siglen, U8* hash, I64 hashlen, I32* stat, U64 key)
{
    U64 reg RDI rdi = sig;
    U64 reg RSI rsi = siglen;
    U64 reg RDX rdx = hash;
    U64 reg RCX rcx = hashlen;
    U64 reg R8 r8 = stat;
    U64 reg R9 r9 = key;
    no_warn rdi, rsi, rdx, rcx, r8, r9;
    asm {
        MOV RAX, RSA_VERIFY_SIGNATURE
        CALL RAX
    }
}

Silent(0);
