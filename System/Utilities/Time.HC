U0 @time_cmos_update_byte(I64 time_reg, I64 val)
{
    OutU8(0x70, time_reg);
    OutU8(0x71, val);
}

I64 @time_dec_to_bcd(I64 val)
{
    return (((val / 10) << 4) | (val % 10));
}

U0 @time_update(U8* date_str, I64 mS_delta, I64 hour_offset)
{
    no_warn mS_delta;
    Bool is_bcd;
    OutU8(0x70, 0x0B);
    if (InU8(0x71) & 4)
        is_bcd = FALSE;
    else
        is_bcd = TRUE;

    I64 date_argc;
    U8** date_argv = String.Split(date_str, ' ', &date_argc);

    I64 month = DefineMatch(date_argv[2], "ST_MONTHS") + 1;
    I64 day = Str2I64(date_argv[1]);
    I64 year = Str2I64(date_argv[3] + 2);
    I64 century = 20;

    date_argv[4][2] = NULL;
    date_argv[4][5] = NULL;

    I64 hour = Str2I64(date_argv[4]);
    I64 minute = Str2I64(date_argv[4] + 3);
    I64 second = Str2I64(date_argv[4] + 6);

    // FIXME: Handle month boundaries, and 12 hour time
    hour += hour_offset;
    if (hour < 0) {
        hour += 24;
        --day;
    } else if (hour > 23) {
        hour -= 24;
        ++day;
    }

    if (is_bcd) {
        century = @time_dec_to_bcd(century);
        year = @time_dec_to_bcd(year);
        month = @time_dec_to_bcd(month);
        day = @time_dec_to_bcd(day);
        hour = @time_dec_to_bcd(hour);
        minute = @time_dec_to_bcd(minute);
        second = @time_dec_to_bcd(second);
    }

    @time_cmos_update_byte(0x32, century);
    @time_cmos_update_byte(0x09, year);
    @time_cmos_update_byte(0x08, month);
    @time_cmos_update_byte(0x07, day);
    @time_cmos_update_byte(0x04, hour);
    @time_cmos_update_byte(0x02, minute);
    @time_cmos_update_byte(0x00, second);
}

Bool @is_dst(I64 month, I64 day, I64 day_of_week, I64 hour)
{
    if (month < 3 || month > 11) {
        return FALSE;
    }
    if (month > 3 && month < 11) {
        return TRUE;
    }
    if (month == 3) {
        if (day < (14 - day_of_week)) {
            return FALSE;
        }
        if (day > (14 - day_of_week) && hour >= 2) {
            return TRUE;
        }
        return FALSE;
    }
    if (month == 11) {
        if (day < (7 - day_of_week)) {
            return TRUE;
        }
        if (day == (7 - day_of_week) && hour < 1) {
            return TRUE;
        }
        return FALSE;
    }
    return FALSE;
}

Bool @time_in_dst()
{
    CDateStruct ds;
    Date2Struct(&ds, Now);
    return @is_dst(ds.mon, ds.day_of_mon, ds.day_of_week, ds.hour);
}

I64 @time_tz_offset()
{
    if (@time_in_dst)
        return -4;
    return -5;
}

U0 @time_query(Bool set = FALSE)
{
    U8 buf[1024];
    @http_url* url = @http_parse_url("http://time.google.com");
    @http_response* resp = Http.Head(url, &buf);
    while (resp->state != HTTP_STATE_DONE)
        Sleep(1);
    I64 mS_delta = cnts.jiffies;
    "Set current date and time to %s ", Json.Get(resp->headers, "Date");
    if (!set)
        set = YorN;
    else
        "\n";
    if (set)
        @time_update(Json.Get(resp->headers, "Date"), mS_delta, @time_tz_offset);
}

U0 TimeSync()
{
    Sleep(500);
    @time_query(1);
}
