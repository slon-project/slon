Silent(1); // This is needed to suppress "Function should return val" warnings for wrappers to non-HolyC functions

class @image
{
    CDC* (*FromBuffer)(U8* buffer, I64 len);
    CDC* (*Load)(U8* filename);
    CDC* (*Write)(U8* filename, CDC* dc);
};

@image Image;

class @image_frame
{
    CDC* dc;
    CSprite* sprite;
    I64 delay;
};

class @image_collection
{
    @image_frame** frames;
    I64 count;
    I64 current;
    I64 jiffies;
    I64 index;
    @image_collection* next;
};

I64 @image_cbgr24_to_4_bit(CBGR24* ptr, Bool dither_probability)
{
    I64 res, k;
    if (dither_probability) {
        k = RandU32;
        if (SqrI64(ptr->r) + SqrI64(ptr->g) + SqrI64(ptr->b) >= 3 * SqrI64(k.u8[0]))
            res = 8;
        else
            res = 0;
        if (ptr->r >= k.u8[1])
            res |= RED;
        if (ptr->g >= k.u8[2])
            res |= GREEN;
        if (ptr->b >= k.u8[3])
            res |= BLUE;
    } else {
        if (SqrI64(ptr->r) + SqrI64(ptr->g) + SqrI64(ptr->b) >= SqrI64(0x80)) {
            res = 8;
            if (ptr->r >= 0x80)
                res |= RED;
            if (ptr->g >= 0x80)
                res |= GREEN;
            if (ptr->b >= 0x80)
                res |= BLUE;
        } else {
            res = 0;
            if (ptr->r >= 0x40)
                res |= RED;
            if (ptr->g >= 0x40)
                res |= GREEN;
            if (ptr->b >= 0x40)
                res |= BLUE;
        }
    }
    return res;
}

#define IMAGE_DITHER_NONE 0
#define IMAGE_DITHER_NATIVE 1
#define IMAGE_DITHER_FLOYDSTEINBERG 2

U0 @image_render_4bit_floydstein(U8* buffer, I32 width, I32 height)
{
    U64 reg RDI rdi = buffer;
    U64 reg RSI rsi = width;
    U64 reg RDX rdx = height;
    no_warn rdi, rsi, rdx;
    asm {
        MOV RAX, RENDER_4BIT_FLOYDSTEIN
        CALL RAX
    }
}

CDC* @image_render_16color_native(U8* pixels, I32 x, I32 y, Bool dither)
{
    I64 i;
    I64 j;
    I64 cnt = 0;
    CBGR24 cbgr24;
    CDC* dc = DCNew(x, y);
    for (i = 0; i < y; i++)
        for (j = 0; j < x; j++) {
            cbgr24.r = pixels[cnt];
            cbgr24.g = pixels[cnt + 1];
            cbgr24.b = pixels[cnt + 2];
            if (!pixels[cnt + 3])
                dc->color = TRANSPARENT;
            else
                dc->color = @image_cbgr24_to_4_bit(&cbgr24, dither);
            GrPlot(dc, j, y - i - 1);
            cnt += 4;
        }
    return dc;
}

CBGR24 @image_palette_std[COLORS_NUM] = {
    0x000000, 0x0000AA, 0x00AA00, 0x00AAAA,
    0xAA0000, 0xAA00AA, 0xAA5500, 0xAAAAAA,
    0x555555, 0x5555FF, 0x55FF55, 0x55FFFF,
    0xFF5555, 0xFF55FF, 0xFFFF55, 0xFFFFFF
};

CBGR24 @image_dif_rgb(CBGR24 from, CBGR24 to)
{
    CBGR24 dif;
    dif.r = to.r - from.r;
    dif.g = to.g - from.g;
    dif.b = to.b - from.b;
    return dif;
}

F64 @image_dist_rgb(CBGR24 from, CBGR24 to)
{
    CBGR24 dif = @image_dif_rgb(from, to);
    F64 dist = dif.r * dif.r + dif.g * dif.g + dif.b * dif.b;
    return dist;
}

I64 @image_get_4bit_color(CBGR24* cbgr24)
{
    F64 dist = -1, tempDist;
    I64 i;
    I64 color = TRANSPARENT;
    for (i = 0; i < COLORS_NUM; i++) {
        tempDist = @image_dist_rgb(*cbgr24, @image_palette_std[i]);
        if (tempDist < dist || dist < 0) {
            dist = tempDist;
            color = i;
        }
    }
    return color;
}

CDC* @image_render_16color_floydsteinberg(U8* pixels, I32 width, I32 height)
{
    @image_render_4bit_floydstein(pixels, width, height);
    I64 i;
    I64 j;
    I64 cnt = 0;
    CBGR24 cbgr24;
    CDC* dc = DCNew(width, height);
    for (i = 0; i < height; i++)
        for (j = 0; j < width; j++) {
            cbgr24.r = pixels[cnt];
            cbgr24.g = pixels[cnt + 1];
            cbgr24.b = pixels[cnt + 2];
            if (!pixels[cnt + 3])
                dc->color = TRANSPARENT;
            else
                dc->color = @image_get_4bit_color(&cbgr24);
            GrPlot(dc, j, height - i - 1);
            cnt += 4;
        }
    return dc;
}

CDC* @image_generate_dc_from_pixels(U8* pixels, I32 width, I32 height, Bool dither = IMAGE_DITHER_FLOYDSTEINBERG)
{
    switch (dither) {
    case IMAGE_DITHER_NONE:
    case IMAGE_DITHER_NATIVE:
        return @image_render_16color_native(pixels, width, height, dither);
        break;
    case IMAGE_DITHER_FLOYDSTEINBERG:
        return @image_render_16color_floydsteinberg(pixels, width, height);
        break;
    default:
        break;
    }
    return NULL;
}

U8* @image_load_gif_from_memory(U8* buffer, I64 len, I64** delays, I64* x, I64* y,
    I64* z)
{
    U64 reg RDI rdi = buffer;
    U64 reg RSI rsi = len;
    U64 reg RDX rdx = delays;
    U64 reg RCX rcx = x;
    U64 reg R8 r8 = y;
    U64 reg R9 r9 = z;
    no_warn rdi, rsi, rdx, rcx, r8, r9;
    asm {
        MOV RAX, IMAGE_LOAD_GIF_FROM_MEMORY
        CALL RAX
    }
}

U8* @stbi_failure_reason()
{
    asm {
        MOV RAX, STBI_FAILURE_REASON
        CALL RAX
    }
}

I32 @stbi_info_from_memory(U8* buffer, I64 len, I64* x, I64* y, I64* comp)
{
    U64 reg RDI rdi = buffer;
    U64 reg RSI rsi = len;
    U64 reg RDX rdx = x;
    U64 reg RCX rcx = y;
    U64 reg R8 r8 = comp;
    no_warn rdi, rsi, rdx, rcx, r8;
    asm {
        MOV RAX, STBI_INFO_FROM_MEMORY
        CALL RAX
    }
}

U8* @stbi_load_from_memory(U8* buffer, I64 len, I64* x, I64* y,
    I64* channels_in_file, I64 desired_channels)
{
    U64 reg RDI rdi = buffer;
    U64 reg RSI rsi = len;
    U64 reg RDX rdx = x;
    U64 reg RCX rcx = y;
    U64 reg R8 r8 = channels_in_file;
    U64 reg R9 r9 = desired_channels;
    no_warn rdi, rsi, rdx, rcx, r8, r9;
    asm {
        MOV RAX, STBI_LOAD_FROM_MEMORY
        CALL RAX
    }
}

U32* @stbi_write_png_to_mem(U32* pixels, I32 stride_bytes, I32 x, I32 y, I32 n, I32* out_len)
{
    U64 reg RDI rdi = pixels;
    U64 reg RSI rsi = stride_bytes;
    U64 reg RDX rdx = x;
    U64 reg RCX rcx = y;
    U64 reg R8 r8 = n;
    U64 reg R9 r9 = out_len;
    no_warn rdi, rsi, rdx, rcx, r8, r9;
    asm {
        MOV RAX, STBI_WRITE_PNG_TO_MEM
        CALL RAX
    }
}

CDC* @image_load(U8* filename)
{
    if (!filename || !FileFind(filename)) {
        PrintErr("Image file not found.\n");
        return NULL;
    }
    I64 len;
    I32 x;
    I32 y;
    I32 comp;
    U8* buffer = FileRead(filename, &len);
    I32 code = @stbi_info_from_memory(buffer, len, &x, &y, &comp);
    if (code != 1) {
        Free(buffer);
        return NULL;
    }
    U8* pixels = @stbi_load_from_memory(buffer, len, &x, &y, &comp, 4);
    Free(buffer);
    CDC* dc = @image_generate_dc_from_pixels(pixels, x, y);
    Free(pixels);
    return dc;
}

U32 @image_rgba_color_table[16] = {
    0xff000000, 0xffaa0000, 0xff00aa00, 0xffaaaa00,
    0xff0000aa, 0xffaa00aa, 0xff0055aa, 0xffaaaaaa,
    0xff555555, 0xffff5555, 0xff55ff55, 0xffffff55,
    0xff5555ff, 0xffff55ff, 0xff55ffff, 0xffffffff
};

U32 @image_get_rgba_color(I64 color)
{
    if (color > 15)
        return 0;
    return @image_rgba_color_table[color];
}

U32* @image_get_rgba_buffer_from_dc_body(CDC* dc)
{
    if (!dc)
        return NULL;
    U32* pixels = CAlloc((dc->width * dc->height) * 4, slon_mem_task);
    I64 x;
    I64 y;
    I64 p = 0;
    for (y = 0; y < dc->height; y++)
        for (x = 0; x < dc->width; x++)
            pixels[p++] = @image_get_rgba_color(GrPeek(dc, x, y));
    return pixels;
}

U0 @image_write(U8* filename, CDC* dc)
{
    if (!dc) {
        PrintErr("Device context is NULL.\n");
        return;
    }
    I32 out_len;
    U32* rgba_buffer = @image_get_rgba_buffer_from_dc_body(dc);
    if (!rgba_buffer) {
        PrintErr("RGBA buffer is NULL.\n");
        return;
    }
    U8* png_buffer = @stbi_write_png_to_mem(rgba_buffer, dc->width * 4, dc->width, dc->height, 4, &out_len);
    if (!png_buffer) {
        PrintErr("PNG buffer is NULL.\n");
        Free(rgba_buffer);
        return;
    }
    FileWrite(filename, png_buffer, out_len);
    Free(rgba_buffer);
    Free(png_buffer);
}

U32 @image_pixel_flip_rgb_bgr(U32 src)
{
    U32 dst;
    dst.u8[0] = src.u8[2];
    dst.u8[1] = src.u8[1];
    dst.u8[2] = src.u8[0];
    dst.u8[3] = src.u8[3];
    return dst;
}

CDC* @image_from_buffer(U8* buffer, I64 len)
{
    I32 x = 0;
    I32 y = 0;
    U8* pixels = NULL;
    CDC* dc = NULL;

    I32 comp;
    I32 code = @stbi_info_from_memory(buffer, len, &x, &y, &comp);
    if (code != 1) {
        return NULL;
    }
    pixels = @stbi_load_from_memory(buffer, len, &x, &y, &comp, 4);
    if (!pixels)
        PopUpOk(@stbi_failure_reason);
    dc = @image_generate_dc_from_pixels(pixels, x, y);
    Free(pixels);
    return dc;
}

@image_collection* @image_collection_from_buffer(U8* buffer, I64 len)
{
    I64 i;
    I32* delays;
    I32 x;
    I32 y;
    I32 z;
    I32 comp;
    I32 code = @stbi_info_from_memory(buffer, len, &x, &y, &comp);
    if (code != 1) {
        return NULL;
    }
    U64 pixels = @image_load_gif_from_memory(buffer, len, &delays, &x, &y, &z);
    if (!pixels)
        PopUpOk(@stbi_failure_reason);
    if (!z)
        return NULL; // no frames?
    @image_collection* collection = CAlloc(sizeof(@image_collection), slon_mem_task);
    @image_frame* frame;
    collection->frames = CAlloc(sizeof(@image_frame*) * z, slon_mem_task);
    collection->count = z;
    for (i = 0; i < z; i++) {
        frame = CAlloc(sizeof(@image_frame), slon_mem_task);
        frame->dc = @image_generate_dc_from_pixels(pixels, x, y);
        frame->sprite = DC2Sprite(frame->dc);
        frame->delay = delays[i];
        collection->frames[i] = frame;
        pixels += (x * y) * 4;
    }
    return collection;
}

Image.FromBuffer = &@image_from_buffer;
Image.Load = &@image_load;
Image.Write = &@image_write;

Silent(0);

U0 Screenshot(U8* custom_filename = NULL, Bool output_filename_to_focus_task = FALSE)
{
    CDC* dc = DCScrnCapture;
    U8 filename[256];
    CDateStruct ds;
    if (custom_filename)
        StrCpy(filename, custom_filename);
    else {
        Date2Struct(&ds, Now);
        StrPrint(filename, "C:/Tmp/ScrnShots/%04d-%02d-%02d-%02d-%02d-%02d.png", ds.year, ds.mon, ds.day_of_mon, ds.hour, ds.min, ds.sec);
    }
    Image.Write(filename, dc);
    DCDel(dc);
    if (output_filename_to_focus_task)
        XTalk(sys_focus_task, filename);
};

U0 @screenshot_hotkey(I64)
{
    Screenshot("C:/Home/Screenshot.png", TRUE);
}

CtrlAltCBSet('S', &@screenshot_hotkey, "", , FALSE);
