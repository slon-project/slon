AutoComplete(0);

U0 @patch_call_rel32(U32 from, U32 to)
{
    *(from(U8*)) = 0xE8;
    *((from + 1)(I32*)) = to - from - 5;
}

U0 @patch_jmp_rel32(U32 from, U32 to)
{
    *(from(U8*)) = 0xE9;
    *((from + 1)(I32*)) = to - from - 5;
}

CMemBlk* ShrinkMemBlkByPags(CMemBlk* from, I64 count)
{
    from->pags -= count;
    U64 to = from;
    to += count * MEM_PAG_SIZE;
    MemCpy(to, from, MEM_PAG_SIZE);
    return to;
}

U0 @sse_enable()
{
    /* clang-format off */
    asm
    {
        MOV_EAX_CR0
        AND AX, 0xFFFB // clear coprocessor emulation CR0.EM
        OR AX, 0x2 // set coprocessor monitoring  CR0.MP
        MOV_CR0_EAX
        MOV_EAX_CR4
        OR AX, 3 << 9 // set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
        MOV_CR4_EAX
    }
    /* clang-format on */
}

U0 @sse_enable_on_all_cores()
{
    I64 i;
    for (i = 1; i < mp_cnt; i++)
        Spawn(&@sse_enable, , , i);
}

I64 @t(Bool _condition, I64 _true, I64 _false)
{
    if (_condition)
        return _true;
    return _false;
}

U0 @slon_mem_task_loop()
{
    while (1) {
        Sleep(1);
    };
}

// Before doing anything else, we:

// 1. Mark memory in code heap below 0x1000000 as used.
sys_code_bp->mem_free_lst->next->pags = 0;

// 2. Free up 64MB at bottom of code heap for non-HolyC programs
sys_code_bp->mem_free_lst = ShrinkMemBlkByPags(sys_code_bp->mem_free_lst, 131072);

// 3. Enable SSE
@sse_enable;

// 4. Init mem_tasks

CTask* slon_mem_task = Spawn(&@slon_mem_task_loop, , "SlonMemTask");

#define MALLOC_MEM_TASK_COUNT 4
CTask** malloc_mem_task = CAlloc(sizeof(CTask*) * MALLOC_MEM_TASK_COUNT, slon_mem_task);
I64 malloc_current_mem_task = 0;

U0 @malloc_mem_tasks_init()
{
    U8* scratch_buffer[64];
    I64 i;
    for (i = 0; i < MALLOC_MEM_TASK_COUNT; i++) {
        StrPrint(scratch_buffer, "SlonMallocTask%d", i);
        malloc_mem_task[i] = Spawn(&@slon_mem_task_loop, , scratch_buffer);
    }
}

@malloc_mem_tasks_init;

U0 dd() { DocDump(adam_task->put_doc); }
//@patch_jmp_rel32(&Dbg2, &Reboot); // Reboot instead of crashing to the debugger
U0 NoBeep(I8, Bool) {};
@patch_jmp_rel32(&Beep, &NoBeep); // Don't delay on beep when entering debugger

Bool BlkDevLock2(CBlkDev* bd)
{
    BlkDevChk(bd);
    while (bd->lock_fwding)
        bd = bd->lock_fwding;
    if (!Bt(&bd->locked_flags, BDlf_LOCKED) || bd->owning_task != Fs) {
        while (LBts(&bd->locked_flags, BDlf_LOCKED))
            Sleep(Rand * 10);
        bd->owning_task = Fs;
        return TRUE;
    } else
        return FALSE;
}

Bool DrvLock2(CDrv* dv)
{
    DrvChk(dv);
    BlkDevLock2(dv->bd);
    if (!Bt(&dv->locked_flags, DVlf_LOCKED) || dv->owning_task != Fs) {
        while (LBts(&dv->locked_flags, DVlf_LOCKED))
            Sleep(Rand * 10);
        dv->owning_task = Fs;
        return TRUE;
    } else
        return FALSE;
}

@patch_jmp_rel32(&BlkDevLock, &BlkDevLock2); // Patch BlkDevLock so we don't deadlock on multiple tasks reading from virtio disk
@patch_jmp_rel32(&DrvLock, &DrvLock2);       // Patch DrvLock so we don't deadlock on multiple tasks reading from virtio disk
