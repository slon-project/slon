// Virtio.HC

//
// PCI virtio I/O registers.
//

#define VIRTIO_PCI_HOST_FEATURES 0  // Features supported by the host
#define VIRTIO_PCI_GUEST_FEATURES 4 // Features activated by the guest
#define VIRTIO_PCI_QUEUE_PFN 8      // PFN for the currently selected queue
#define VIRTIO_PCI_QUEUE_SIZE 12    // Queue size for the currently selected queue
#define VIRTIO_PCI_QUEUE_SEL 14     // Queue selector
#define VIRTIO_PCI_QUEUE_NOTIFY 16  // Queue notifier
#define VIRTIO_PCI_STATUS 18        // Device status register
#define VIRTIO_PCI_ISR 19           // Interrupt status register
#define VIRTIO_PCI_CONFIG 20        // Configuration data block

//
// PCI virtio status register bits
//

#define VIRTIO_CONFIG_S_ACKNOWLEDGE 1
#define VIRTIO_CONFIG_S_DRIVER 2
#define VIRTIO_CONFIG_S_DRIVER_OK 4
#define VIRTIO_CONFIG_S_FAILED 0x80

//
// Ring descriptor flags
//

#define VRING_DESC_F_NEXT 1     // Buffer continues via the next field
#define VRING_DESC_F_WRITE 2    // Buffer is write-only (otherwise read-only)
#define VRING_DESC_F_INDIRECT 4 // Buffer contains a list of buffer descriptors

class @virtio_queue_buf
{
    U64 address;
    U32 length;
    U16 flags;
    U16 next;
};
class @virtio_avail
{
    U16 flags;
    U16 index;
    U16 ring[256];
    U16 int_index;
};
class @virtio_used_item
{
    U32 index;
    U32 length;
};
class @virtio_used
{
    U16 flags;
    U16 index;
    @virtio_used_item ring[256];
    U16 int_index;
};
class @virtio_queue
{
    @virtio_queue_buf buffers[256];
    @virtio_avail available;
    U8 padding[3578];
    @virtio_used used;
};

class @virtio_avail_buf
{
    U32 index;
    U64 address;
    U32 length;
};

class @virtio_buf_info
{
    U8* buffer;
    U64 size;
    U8 flags;

    // If the user wants to keep same buffer as passed in this struct, use "true".
    // otherwise, the supplied buffer will be copied in the queues' buffer
    Bool copy;
};

// Virtio-blk.HC

#define BDT_VIRTIO_BLK 10

#define VIRTIO_BLK_T_IN 0
#define VIRTIO_BLK_T_OUT 1
#define VIRTIO_BLK_T_FLUSH 4

#define VIRTIO_BLK_MAX_BLK 0x400000 // Limit blkdev to 2G max, set to NULL to use entire disk (not recommended for RedSea)

class @virtio_blk
{
    U16 port;
    U32 blks;
    @virtio_queue* vq;
    I64 vq_size;
    I64 vq_index;
    U8 status;
};

class @virtio_blk_request
{
    U32 type;
    U32 priority;
    U64 sector;
};

@virtio_blk virtio_blk;
MemSet(&virtio_blk, 0, sizeof(@virtio_blk));

I64 VirtioBlkInit()
{
    I64 j;

    // Scan for device
    j = PCIClassFind(0x010000, 0);
    if (j < 0) {
        "\n[virtio-blk] No device found\n";
        return -1;
    }
    virtio_blk.port = PCIReadU32(j.u8[2],
                          j.u8[1], j.u8[0], 0x10)
        & 0xFFFFFFFC;

    virtio_blk.blks = InU32(virtio_blk.port + VIRTIO_PCI_CONFIG);

    // Reset Device
    OutU8(virtio_blk.port + VIRTIO_PCI_STATUS, 0);

    // Found Driver
    OutU8(virtio_blk.port + VIRTIO_PCI_STATUS, InU8(virtio_blk.port + VIRTIO_PCI_STATUS) | VIRTIO_CONFIG_S_ACKNOWLEDGE | VIRTIO_CONFIG_S_DRIVER);

    // Set up virt queue
    OutU16(virtio_blk.port + VIRTIO_PCI_QUEUE_SEL, 0);
    virtio_blk.vq_size = InU16(virtio_blk.port + VIRTIO_PCI_QUEUE_SIZE); // 256
    virtio_blk.vq = CAllocAligned(sizeof(@virtio_queue), 4096, slon_mem_task->code_heap);
    OutU32(virtio_blk.port + VIRTIO_PCI_QUEUE_PFN, virtio_blk.vq / 4096);

    // Init OK
    OutU8(virtio_blk.port + VIRTIO_PCI_STATUS, InU8(virtio_blk.port + VIRTIO_PCI_STATUS) | VIRTIO_CONFIG_S_DRIVER_OK);
    virtio_blk.vq_index = 0;
}

// DskVIO.HC

U0 VIOFlush()
{
    I64 j;
    I64 vq_idx;
    @virtio_blk_request* brq = CAlloc(sizeof(@virtio_blk_request), slon_mem_task);
    brq->type = VIRTIO_BLK_T_FLUSH;
    brq->sector = NULL;
    vq_idx = virtio_blk.vq->available.index % 256;
    virtio_blk.vq->buffers[virtio_blk.vq_index % 256].address = brq;
    virtio_blk.vq->buffers[virtio_blk.vq_index % 256].length = sizeof(@virtio_blk_request);
    virtio_blk.vq->buffers[virtio_blk.vq_index % 256].flags = VRING_DESC_F_NEXT;
    virtio_blk.vq->buffers[virtio_blk.vq_index % 256].next = (virtio_blk.vq_index + 1) % 256;
    virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].address = &virtio_blk.status;
    virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].length = 1;
    virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].flags = VRING_DESC_F_WRITE;
    virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].next = 0;
    virtio_blk.vq->available.ring[vq_idx] = virtio_blk.vq_index % 256;
    virtio_blk.vq_index += 2;
    j = virtio_blk.vq->used.index;
    virtio_blk.vq->available.index++;
    OutU16(virtio_blk.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
    while (j == virtio_blk.vq->used.index) {
        Yield;
    }
    Free(brq);
}

Bool VIORBlks(CDrv* dv, U8* buf, I64 blk, I64 cnt)
{
    no_warn dv;
    I64 i, j;
    I64 vq_idx;
    U64 addr;
    @virtio_blk_request* brq = CAlloc(sizeof(@virtio_blk_request), slon_mem_task);
    for (i = 0; i < cnt; i++) {
        brq->type = VIRTIO_BLK_T_IN;
        brq->sector = blk + i;
        vq_idx = virtio_blk.vq->available.index % 256;
        addr = buf + (BLK_SIZE * i);
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].address = brq;
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].length = sizeof(@virtio_blk_request);
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].flags = VRING_DESC_F_NEXT;
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].next = (virtio_blk.vq_index + 1) % 256;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].address = addr;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].length = BLK_SIZE;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].flags = VRING_DESC_F_WRITE | VRING_DESC_F_NEXT;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].next = (virtio_blk.vq_index + 2) % 256;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].address = &virtio_blk.status;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].length = 1;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].flags = VRING_DESC_F_WRITE;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].next = 0;
        virtio_blk.vq->available.ring[vq_idx] = virtio_blk.vq_index % 256;
        virtio_blk.vq_index += 3;
        j = virtio_blk.vq->used.index;
        virtio_blk.vq->available.index++;
        OutU16(virtio_blk.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
        while (j == virtio_blk.vq->used.index) {
            Yield;
        }
    }
    Free(brq);
    return TRUE;
}

Bool VIOWBlks(CDrv* dv, U8* buf, I64 blk, I64 cnt)
{
    no_warn dv;
    I64 i, j;
    I64 vq_idx;
    U64 addr;
    @virtio_blk_request* brq = CAlloc(sizeof(@virtio_blk_request), slon_mem_task);
    for (i = 0; i < cnt; i++) {
        brq->type = VIRTIO_BLK_T_OUT;
        brq->sector = blk + i;
        vq_idx = virtio_blk.vq->available.index % 256;
        addr = buf + (BLK_SIZE * i);
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].address = brq;
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].length = sizeof(@virtio_blk_request);
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].flags = VRING_DESC_F_NEXT;
        virtio_blk.vq->buffers[virtio_blk.vq_index % 256].next = (virtio_blk.vq_index + 1) % 256;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].address = addr;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].length = BLK_SIZE;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].flags = VRING_DESC_F_NEXT;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 1) % 256].next = (virtio_blk.vq_index + 2) % 256;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].address = &virtio_blk.status;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].length = 1;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].flags = VRING_DESC_F_WRITE;
        virtio_blk.vq->buffers[(virtio_blk.vq_index + 2) % 256].next = 0;
        virtio_blk.vq->available.ring[vq_idx] = virtio_blk.vq_index % 256;
        virtio_blk.vq_index += 3;
        j = virtio_blk.vq->used.index;
        virtio_blk.vq->available.index++;
        OutU16(virtio_blk.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
        while (j == virtio_blk.vq->used.index) {
            Yield;
        }
    }
    Free(brq);
    VIOFlush;
    return TRUE;
}

U0 RedSeaTryInit(CDrv* dv)
{
    CRedSeaBoot br;
    Bool unlock;
    try {
        unlock = DrvLock(dv);
        BlkRead(dv, &br, dv->drv_offset, 1);
        if (br.signature != MBR_PT_REDSEA || br.signature2 != 0xAA55)
            return;
        dv->fs_type = FSt_REDSEA;
        CallExtStr("RedSeaFreeFreeLst", dv);
        dv->spc = 1;
        dv->size = br.sects;
        dv->data_area = dv->drv_offset + br.bitmap_sects;
        dv->root_clus = br.root_clus;
        dv->fat1 = dv->fat2 = dv->drv_offset + 1;
        CallExtStr("DrvFATBlkAlloc", dv);
        if (unlock)
            DrvUnlock(dv);
    } catch if (unlock)
        DrvUnlock(dv);
}

U8 MountVirtioBlk()
{ // Mount Virtio-blk device
    CDrv* dv = DrvMakeFreeSlot(DrvNextFreeLet('A'));
    CBlkDev* bd = BlkDevNextFreeSlot(dv->drv_let, BDT_RAM);
    CRedSeaBoot* bs = CAlloc(BLK_SIZE, slon_mem_task);
    bd->max_blk = 512;
    BlkDevAdd(bd, , TRUE, TRUE);
    bd->type = BDT_VIRTIO_BLK;
    if (VIRTIO_BLK_MAX_BLK) {
        bd->max_blk = Min(VIRTIO_BLK_MAX_BLK, virtio_blk.blks);
    } else {
        bd->max_blk = virtio_blk.blks;
    }
    Free(bd->RAM_dsk);
    dv->size = bd->max_blk + 1 - bd->drv_offset;
    VIORBlks(dv, bs, 0, 1);
    dv->root_clus = bs->root_clus;
    dv->data_area = bs->bitmap_sects;
    dv->next_free = NULL;
    dv->last_free = NULL;
    Free(bs);
    RedSeaTryInit(dv);
    return dv->drv_let;
}

// DskBlk2.HC

Bool BlkRead2(CDrv* dv, U8* buf, I64 blk, I64 cnt)
{ // Read blk cnt from Drv to buf.
    Bool res = TRUE, unlock;
    CBlkDev* bd = dv->bd;
    if (cnt <= 0)
        return TRUE;
    DrvChk(dv);
    try {
        unlock = DrvLock(dv);
        CallExtStr("BlkDevInit", bd);
        if (dv->drv_offset && blk < dv->drv_offset || blk + cnt > dv->drv_offset + dv->size)
            throw('Drv');
        if (bd->flags & BDF_READ_CACHE)
            CallExtStr("RCache", dv, &buf, &blk, &cnt);
        if (cnt > 0) {
            switch (bd->type) {
            case BDT_RAM:
                MemCpy(buf, bd->RAM_dsk + blk << BLK_SIZE_BITS, cnt << BLK_SIZE_BITS);
                break;
            case BDT_ISO_FILE_READ:
            case BDT_ISO_FILE_WRITE:
                FBlkRead(bd->file_dsk, buf, blk, cnt);
                break;
            case BDT_ATA:
            case BDT_ATAPI:
                res = CallExtStr("ATARBlks", dv, buf, blk, cnt);
                break;
            case BDT_VIRTIO_BLK:
                res = VIORBlks(dv, buf, blk, cnt);
                break;
            }
            bd->last_time = tS;
            if (bd->flags & BDF_READ_CACHE)
                CallExtStr("DskCacheAdd", dv, buf, blk, cnt);
        }
        if (unlock)
            DrvUnlock(dv);
    } catch if (unlock)
        DrvUnlock(dv);
    return res;
}

Bool BlkWrite2(CDrv* dv, U8* buf, I64 blk, I64 cnt)
{ // Write blk cnt from buf to Drv.
    Bool res = TRUE, unlock;
    CBlkDev* bd = dv->bd;
    if (cnt <= 0)
        return TRUE;
    DrvChk(dv);
    try {
        unlock = DrvLock(dv);
        CallExtStr("BlkDevInit", bd);
        if (bd->flags & BDF_READ_ONLY && !(bd->flags & BDF_READ_ONLY_OVERRIDE))
            throw('BlkDev');
        if (dv->drv_offset && blk < dv->drv_offset || blk + cnt > dv->drv_offset + dv->size)
            throw('Drv');
        if (cnt > 0) {
            switch (bd->type) {
            case BDT_RAM:
                MemCpy(bd->RAM_dsk + blk << BLK_SIZE_BITS, buf, cnt << BLK_SIZE_BITS);
                break;
            case BDT_ISO_FILE_READ:
            case BDT_ISO_FILE_WRITE:
                FBlkWrite(bd->file_dsk, buf, blk, cnt);
                break;
            case BDT_ATA:
            case BDT_ATAPI:
                res = CallExtStr("ATAWBlks", dv, buf, blk, cnt);
                break;
            case BDT_VIRTIO_BLK:
                res = VIOWBlks(dv, buf, blk, cnt);
                break;
            }
            bd->last_time = tS;
            if (bd->flags & BDF_READ_CACHE)
                CallExtStr("DskCacheAdd", dv, buf, blk, cnt);
        }
        if (unlock)
            DrvUnlock(dv);
    } catch if (unlock)
        DrvUnlock(dv);
    return res;
}

@patch_jmp_rel32(&BlkRead, &BlkRead2);
@patch_jmp_rel32(&BlkWrite, &BlkWrite2);

// DskBlkDev2.HC

CBlkDev* BlkDevChk2(CBlkDev* bd, Bool except = TRUE)
{ // Check for valid BlkDev. Throw exception.
    if (bd->type == BDT_VIRTIO_BLK)
        return bd;
    if (!bd || bd->bd_signature != BD_SIGNATURE_VAL || !(BDT_NULL < bd->type < BDT_TYPES_NUM)) {
        if (except)
            throw('BlkDev');
        else
            return NULL;
    } else
        return bd;
}

@patch_jmp_rel32(&BlkDevChk, &BlkDevChk2);

// DskDrv2.HC

DefineLstLoad("ST_BLKDEV_TYPES2",
    "NULL\0RAM\0ATA\0FILE_READ\0FILE_WRITE\0ATAPI\0NULL\0NULL\0NULL\0NULL\0VIRTIO\0");

U8 DrvTextAttrGet2(U8 drv_let = 0)
{ // Get color of drive.
    U8* blkdev_text_attr2 = blkdev_text_attr;
    U8* drv_text_attr2 = drv_text_attr;
    I64 dta_size = 3;
    drv_let = Let2Let(drv_let);
    if (drv_let == 'A')
        return BLACK << 4 | WHITE;
    if ('A' <= drv_let <= 'Z')
        return blkdev_text_attr2[Let2BlkDevType(drv_let)] << 4 | drv_text_attr2[drv_let % dta_size];
    else
        return BLACK << 4 | WHITE;
}

U0 DrvRep2()
{ // Drive report.
    CDrv* dv;
    CBlkDev* bd;
    I64 ch, i, drv_let, attr;
    U8* st;
    "\nDefined Drives:\n";
    for (i = 0, dv = blkdev.drvs; i < DRVS_NUM; i++, dv++) {
        if (dv->dv_signature == DRV_SIGNATURE_VAL) {
            bd = dv->bd;
            drv_let = Drv2Let(dv);
            if (Bt(&dv->fs_type, FStf_DISABLE))
                ch = '-';
            else if (drv_let == blkdev.boot_drv_let)
                ch = ':';
            else
                ch = '+';
            attr = DrvTextAttrGet(drv_let);
            "\dFG,%d\d\dBG,%d\d%C %-8Z %-10Z %04X %04X %02X\n",
                attr & 15, attr >> 4, drv_let, dv->fs_type &FSG_TYPE_MASK, "ST_DRV_TYPES",
                bd->type, "ST_BLKDEV_TYPES2", bd->base0, bd->base1, bd->unit;
            if (st = DrvModelNum(drv_let)) {
                "Model#:%s\n", st;
                Free(st);
            }
            if (st = DrvSerialNum(drv_let)) {
                "Serial#:%s\n", st;
                Free(st);
            }
            if (bd->type == BDT_ISO_FILE_READ || bd->type == BDT_ISO_FILE_WRITE)
                "File=\"%s\"\n", bd->file_dsk_name;
            "%016X-%016X\n\dFG\d\dBG\d", dv->drv_offset, dv->drv_offset + dv->size - 1;
        }
    }
    "Home Dir:\"%s\"\n", blkdev.home_dir;
}

@patch_jmp_rel32(&DrvTextAttrGet, &DrvTextAttrGet2);
@patch_jmp_rel32(&DrvRep, &DrvRep2);

VirtioBlkInit;
MountVirtioBlk;

if (Let2Drv('A', 0) && !Let2Drv('A')->root_clus) {
    "[virtio-blk] RedSea filesystem not initialized, formatting.\n";
    Fmt('A', , FALSE, FSt_REDSEA);
    Cd("M:/System/");
}
