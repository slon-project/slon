U0 _Z8os_blinkPKc()
{
    // os_blink(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    F64 frequency = Str2F64(p0);
    Print("called os_blink(%.1f)\n", frequency);
    Blink(frequency);
    POP_SYSV_REGS
}

U64 @os_call(U8* function_name, U64 arg)
{
    if (!function_name)
        return NULL;
    if (!StrLen(function_name))
        return NULL;
    CHash* h = HashFind(function_name, Fs->hash_table, Fs->hash_table->mask);
    if (!h)
        return NULL;
    if (h->type & HTT_FUN == HTT_FUN) {
        CallInd(h(CHashFun*)->exe_addr, arg);
    } else {
        return NULL;
    }
}

U0 _Z7os_callmm()
{
    // os_call(unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_call(p0, p1);
    POP_SYSV_REGS
}

U0 _Z16os_device_callocj()
{
    // os_device_calloc(unsigned int)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    CAllocAligned(p0, 4096, slon_mem_task->code_heap);
    POP_SYSV_REGS
}

U0 _Z7os_exitv()
{
    // os_exit()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    UserTaskCont;
    POP_SYSV_REGS
}

U8* @os_file_picker(U8* path, U8* glob)
{
    U8* full_path = CAlloc(StrLen(path) + StrLen(glob) + 4, slon_mem_task);
    CatPrint(full_path, "%s/%s", path, glob);

    CDirEntry* de = FilesFind(full_path);
    Free(full_path);

    CDirEntry* tmpde;
    U8* file_list = NULL;
    U8* selected_file = NULL;
    I64 list_pos = 0;
    I64 list_size = 0;

    tmpde = de;
    while (tmpde) {
        list_size += StrLen(tmpde->name) + 2;
        tmpde = tmpde->next;
    }

    file_list = CAlloc(list_size, slon_mem_task);

    tmpde = de;
    while (tmpde) {
        StrCpy(file_list + list_pos, tmpde->name);
        list_pos += StrLen(tmpde->name) + 1;
        tmpde = tmpde->next;
    }

    I64 list_index = Adam("PopUpPickLst(0x%08x);\n", file_list);
    Free(file_list);
    list_pos = 0;

    if (list_index < 0) {
        DirTreeDel(de);
        return StrNew("", slon_mem_task);
    }

    tmpde = de;
    while (tmpde) {
        if (list_index == list_pos) {
            selected_file = CAlloc(StrLen(path) + StrLen(tmpde->name) + 4, slon_mem_task);
            CatPrint(selected_file, "%s/%s", path, tmpde->name);
            break;
        }
        StrCpy(file_list + list_pos, tmpde->name);
        list_pos++;
        tmpde = tmpde->next;
    }

    DirTreeDel(de);
    return selected_file;
}

U0 _Z14os_file_pickerPKcS0_()
{
    // os_file_picker(char const*, char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_file_picker(p0, p1);
    POP_SYSV_REGS
}

U8* @os_files_list(U8* path)
{
    U8* full_path = CAlloc(StrLen(path) + 4, slon_mem_task);
    CatPrint(full_path, "%s", path);

    CDirEntry* de = FilesFind(full_path);
    Free(full_path);

    CDateStruct ds;
    CDirEntry* tmpde;
    U8* file_list = NULL;
    I64 list_size = 0;

    tmpde = de;
    while (tmpde) {
        list_size += StrLen(tmpde->name) + 48; // Should be enough for filename, date,
                                               // filesize + semicolon separators
        tmpde = tmpde->next;
    }

    if (!list_size)
        return NULL;

    file_list = CAlloc(list_size, slon_mem_task);

    tmpde = de;
    I64 counter = 0;

    while (tmpde) {
        if (counter > 0) {
            StrCpy(file_list + StrLen(file_list), "|");
        }
        StrCpy(file_list + StrLen(file_list), tmpde->name);
        if (tmpde->attr & RS_ATTR_DIR)
            StrCpy(file_list + StrLen(file_list), "/");
        StrCpy(file_list + StrLen(file_list), ";");
        Date2Struct(&ds, tmpde->datetime);
        StrPrint(file_list + StrLen(file_list), "%04d-%02d-%02d %02d:%02d", ds.year,
            ds.mon, ds.day_of_mon, ds.hour, ds.min);
        StrCpy(file_list + StrLen(file_list), ";");
        StrPrint(file_list + StrLen(file_list), "%d", tmpde->size);
        tmpde = tmpde->next;
        counter++;
    }

    DirTreeDel(de);
    return file_list;
}

U0 _Z14os_path_existsPKc()
{
    // os_path_exists(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    FileFind(p0);
    POP_SYSV_REGS
}

U0 _Z13os_files_listPKc()
{
    // os_files_list(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_files_list(p0);
    POP_SYSV_REGS
}

Bool @os_is_vm()
{
    CRAXRBCRCXRDX res;
    CPUId(0x40000000, &res);
    if (res.rbx == 0x4B4D564B)
        return TRUE;
    return FALSE;
}

U0 _Z8os_is_vmv()
{
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_is_vm;
    POP_SYSV_REGS
}

U0 @os_pc_speaker(F64 frequency)
{
    I64 period;
    if (!frequency)
        OutU8(0x61, InU8(0x61) & ~3);
    else {
        period = ClampI64(SYS_TIMER_FREQ / frequency, 1, U16_MAX);
        OutU8(0x43, 0xB6);
        OutU8(0x42, period);
        OutU8(0x42, period.u8[1]);
        OutU8(0x61, 3 | InU8(0x61));
    }
}

U0 _Z13os_pc_speakerPKc()
{
    // os_pc_speaker(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    F64 frequency = Str2F64(p0);
    @os_pc_speaker(frequency);
    POP_SYSV_REGS
}

U0 _Z9os_randomv()
{
    // os_random()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    RandU64;
    POP_SYSV_REGS
}

U0 _Z19os_read_entire_filePKcPl()
{
    // os_read_entire_file(char const*, long*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    FileRead(p0, p1);
    POP_SYSV_REGS
}

U0 @os_screenshot()
{
    CDC* dc = DCScrnCapture(, slon_mem_task);
    Image.Write("B:/screenshot.png", dc);
    DCDel(dc);
}

U0 _Z13os_screenshotv()
{
    // os_screenshot()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_screenshot;
    POP_SYSV_REGS
}

U8* @os_to_uppercase(U8* instr)
{
    if (!instr)
        return NULL;
    if (!StrLen(instr))
        return NULL;
    U8* outstr = CAlloc(StrLen(instr) + 1, slon_mem_task);
    I64 i;
    for (i = 0; i < StrLen(instr); i++)
        outstr[i] = ToUpper(instr[i]);
    return outstr;
}

U0 _Z15os_to_uppercasePKc()
{
    // os_to_uppercase(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @os_to_uppercase(p0);
    POP_SYSV_REGS
}

U0 _Z20os_write_entire_filePKcPhl()
{
    // os_write_entire_file(char const*, unsigned char*, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    FileWrite(p0, p1, p2);
    POP_SYSV_REGS
}
