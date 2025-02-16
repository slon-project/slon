U0 _Z8dc_aliasm()
{
    // dc_alias(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCAlias(p0);
    POP_SYSV_REGS
}

U0 _Z7dc_blotmmmm()
{
    // dc_blot(unsigned long, unsigned long, unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrBlot(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U8* @dc_buffer(CDC* dc) { return dc->body; }

U0 _Z9dc_bufferm()
{
    // dc_buffer(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_buffer(p0);
    POP_SYSV_REGS
}

I64 @dc_color(CDC* dc) { return dc->color; }

U0 _Z8dc_colorm()
{
    // dc_color(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_color(p0);
    POP_SYSV_REGS
}

U0 @dc_copy(CDC* dest, I64 x, I64 y, CDC* src)
{

    // If position is off-screen, return
    if (x > dest->width - 1 || y > dest->height - 1)
        return;

    // If device context dimensions match, MemCpy and return
    if (dest->width_internal == src->width_internal && dest->height == src->height) {
        MemCpy(dest->body, src->body, dest->width_internal * dest->height);
        return;
    }

    CDC* dc1 = DCAlias(dest);
    CDC* dc2 = DCAlias(src);

    I64 src_line = 0;
    I64 src_row = 0;
    I64 clip_y = 0;

    // Handle horizontal clipping left
    while (x < 0) {
        dc2->x0++;
        x++;
    }

    // Handle vertical clipping top
    while (y < 0) {
        dc2->body += src->width_internal;
        dc2->y0++;
        y++;
    }

    // default, clip line to copy as width-left off screen
    src_line = src->width - dc2->x0;

    if (-dc2->x0 + x + src->width >= dest->width) {
        src_line -= ((-dc2->x0 + x + src->width) - dest->width);
    }

    dc2->body += dc2->x0;
    clip_y = y;

    while (src_row < (src->height - dc2->y0) && clip_y < dest->height) {
        MemCpy(dc1->body + (y * dest->width) + x, dc2->body, src_line);
        dc2->body += src->width_internal;
        dc1->body += dest->width_internal;
        clip_y++;
        src_row++;
    }

    Free(dc2);
    Free(dc1);
}

U0 _Z7dc_copymmmm()
{
    // dc_copy(unsigned long, unsigned long, unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_copy(p0, p1, p2, p3);
    POP_SYSV_REGS
}

U0 _Z10dc_destroym()
{
    // dc_destroy(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCDel(p0);
    POP_SYSV_REGS
}

U0 _Z14dc_draw_circlemlll()
{
    // dc_draw_circle(unsigned long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrCircle3(p0, p1, p2, 0, p3);
    POP_SYSV_REGS
}

U0 _Z19dc_draw_filled_rectmllll()
{
    // dc_draw_filled_rect(unsigned long, long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrRect(p0, p1, p2, p3, p4);
    POP_SYSV_REGS
}

U0 _Z12dc_draw_linemllll()
{
    // dc_draw_line(unsigned long, long, long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrLine3(p0, p1, p2, 0, p3, p4, 0);
    POP_SYSV_REGS
}

U0 _Z13dc_draw_pixelmll()
{
    // dc_draw_pixel(unsigned long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrPlot(p0, p1, p2);
    POP_SYSV_REGS
}

U0 _Z7dc_fillmm()
{
    // dc_fill(unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCFill(p0, p1);
    POP_SYSV_REGS
}

CDC* @dc_gr_dc() { return gr.dc; }

U0 _Z8dc_gr_dcv()
{
    // dc_gr_dc()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_gr_dc();
    POP_SYSV_REGS
}

I64 @dc_height(CDC* dc) { return dc->height; }

U0 _Z9dc_heightm()
{
    // dc_height(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_height(p0);
    POP_SYSV_REGS
}

U0 _Z17dc_load_from_filePKc()
{
    // dc_load_from_file(char const*)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GRRead(p0);
    POP_SYSV_REGS
}

U0 _Z6dc_newmm()
{
    // dc_new(unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCNew(p0, p1);
    POP_SYSV_REGS
}

U0 _Z11dc_pixel_atmll()
{
    // dc_pixel_at(unsigned long, long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GrPeek(p0, p1, p2);
    POP_SYSV_REGS
}

U0 _Z16dc_replace_colormmm()
{
    // dc_replace_color(unsigned long, unsigned long, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCColorChg(p0, p1, p2);
    POP_SYSV_REGS
}

U0 _Z13dc_screenshotv()
{
    // dc_screenshot()
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    DCScrnCapture(1);
    POP_SYSV_REGS
}

U0 _Z15dc_save_to_filePKcm()
{
    // dc_save_to_file(char const*, unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    GRWrite(p0, p1);
    POP_SYSV_REGS
}

U0 @dc_set_color(CDC* dc, I64 color) { dc->color = color; }

U0 _Z12dc_set_colorml()
{
    // dc_set_color(unsigned long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_set_color(p0, p1);
    POP_SYSV_REGS
}

U0 @dc_set_thickness(CDC* dc, I64 thickness) { dc->thick = thickness; }

U0 _Z16dc_set_thicknessml()
{
    // dc_set_thickness(unsigned long, long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_set_thickness(p0, p1);
    POP_SYSV_REGS
}

I64 @dc_thickness(CDC* dc) { return dc->thick; }

U0 _Z12dc_thicknessm()
{
    // dc_thickness(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_thickness(p0);
    POP_SYSV_REGS
}

I64 @dc_width(CDC* dc) { return dc->width; }

U0 _Z8dc_widthm()
{
    // dc_width(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_width(p0);
    POP_SYSV_REGS
}

I64 @dc_width_internal(CDC* dc) { return dc->width_internal; }

U0 _Z17dc_width_internalm()
{
    // dc_width_internal(unsigned long)
    PUSH_SYSV_REGS
    GET_SYSV_ARGS
    @dc_width_internal(p0);
    POP_SYSV_REGS
}