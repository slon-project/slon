#define PUSH_SYSV_REGS \
    asm {PUSH RCX PUSH RDX PUSH RBX PUSH RBP PUSH RSI PUSH RDI PUSH R8 PUSH R9 PUSH   \
      R10 PUSH R11 PUSH R12 PUSH R13 PUSH R14 PUSH R15}
#define POP_SYSV_REGS \
    p0 = p0;          \
    p1 = p1;          \
    p2 = p2;          \
    p3 = p3;          \
    p4 = p4;          \
    p5 = p5;          \
    asm {POP R15 POP R14 POP R13 POP R12 POP R11 POP R10 POP R9 POP R8 POP RDI POP    \
      RSI POP RBP POP RBX POP RDX POP RCX}
#define GET_SYSV_ARGS                              \
    asm {PUSH R9 PUSH R8 PUSH RCX PUSH RDX PUSH RSI PUSH RDI} \
    I64 reg RDI p0;                                \
    I64 reg RSI p1;                                \
    I64 reg RDX p2;                                \
    I64 reg RCX p3;                                \
    I64 reg R8 p4;                                 \
    I64 reg R9 p5;                                 \
    asm {POP RDI POP RSI POP RDX POP RCX POP R8 POP R9}

#define MOV_ANS_RAX asm { MOV[&ans], RAX }
#define MOV_PARAM0_RDI asm {MOV [&param0], RDI}

I64 param0;
I64 elf_argc;
U8** elf_argv;

asm {
_ELF_CALL::
        PUSH    RBP
        MOV     RBP,RSP
        MOV     RAX,U64 SF_ARG1[RBP]
        MOV     RDI,U64 SF_ARG2[RBP]
        MOV     RSI,U64 SF_ARG3[RBP]
        TEST    RAX,RAX
        JZ      @@05
        CALL    RAX
@@05:   POP     RBP
        RET1    8
}

U0 _main()
{
    MOV_PARAM0_RDI
    CallInd(_ELF_CALL, param0, elf_argc, elf_argv);
    UserTaskCont;
}

U0 _exit() { UserTaskCont; }
