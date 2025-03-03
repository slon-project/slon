#define TRIM_BOTH 0
#define TRIM_LEFT 1
#define TRIM_RIGHT 2

U0 @string_append(U8* dst, U8* fmt, ...)
{
    U8* buf;
    if (argc) {
        buf = StrPrintJoin(NULL, fmt, argc, argv);
    } else {
        buf = StrNew(fmt, adam_task);
    }
    U8* src = buf;
    StrCpy(dst + StrLen(dst), src);
    Free(buf);
}

Bool @string_is_number(U8* s)
{
    while (*s) {
        switch (*s) {
        case '-':
        case '.':
        case '0' ... '9':
            break;
        default:
            return FALSE;
            break;
        }
        s++;
    }
    return TRUE;
}

Bool @string_begins_with(U8* fragment, U8* str)
{
    if (!fragment || !str)
        return FALSE;
    if (StrLen(fragment) > StrLen(str))
        return FALSE;
    return !MemCmp(fragment, str, StrLen(fragment));
}

Bool @string_ends_with(U8* fragment, U8* str)
{
    if (!fragment || !str)
        return FALSE;
    if (StrLen(fragment) > StrLen(str))
        return FALSE;
    return !MemCmp(fragment, str + StrLen(str) - StrLen(fragment), StrLen(fragment));
}

U8* @string_replace(U8* s, U8* oldW, U8* newW)
{
    if (!StrFind(oldW, s)) {
        return StrNew(s, adam_task);
    }
    U8* result;
    I64 i, cnt = 0;
    I64 newWlen = StrLen(newW);
    I64 oldWlen = StrLen(oldW);
    for (i = 0; s[i] != NULL; i++) {
        if (StrFind(oldW, &s[i]) == &s[i]) {
            cnt++;

            i += oldWlen - 1;
        }
    }
    result = MAlloc(i + cnt * (newWlen - oldWlen) + 1, adam_task);
    i = 0;
    while (*s) {
        if (StrFind(oldW, s) == s) {
            StrCpy(&result[i], newW);
            i += newWlen;
            s += oldWlen;
        } else
            result[i++] = *s++;
    }
    result[i] = NULL;
    return result;
}

U8** @string_split(U8* s, U8 ch = '\n', I64* cnt)
{
    U8 check_buf[4];
    StrPrint(check_buf, "%c", ch);
    if (!StrFind(check_buf, s)) {
        U8** same_arr = CAlloc(sizeof(U8*) * 1, adam_task);
        same_arr[0] = s;
        *cnt = 1;
        return same_arr;
    }
    U8* p = s;
    cnt[0] = 0;
    while (*p) {
        if (*p == ch)
            cnt[0]++;
        p++;
    }
    if (!(cnt[0]))
        return NULL;
    cnt[0]++;
    I64 i = -1;
    U8** arr = CAlloc(sizeof(U8*) * cnt[0], adam_task);
    p = s;
    while (*p) {
        if (*p == ch || i < 0) {
            i++;
            arr[i] = p;
            if (*p == ch) {
                arr[i]++;
                *p = NULL;
            }
        }
        p++;
    }
    return arr;
}

Bool @string_trim_ch(U8 s_ch, U8 trim_ch)
{
    if (!s_ch) {
        return FALSE;
    }
    if (!trim_ch) {
        return (s_ch == ' ' || s_ch == '\r' || s_ch == '\n' || s_ch == '\t');
    } else {
        return (s_ch == trim_ch);
    }
}

U0 @string_trim(U8* s, U8 ch = NULL, I64 mode = TRIM_BOTH)
{
    Bool trim_ch = @string_trim_ch(*s, ch);
    if (TRIM_BOTH || TRIM_LEFT) {
        while (trim_ch) {
            StrCpy(s, s + 1);
            trim_ch = @string_trim_ch(*s, ch);
        }
    }
    trim_ch = @string_trim_ch(s[StrLen(s) - 1], ch);
    if (TRIM_BOTH || TRIM_RIGHT) {
        while (trim_ch) {
            s[StrLen(s) - 1] = NULL;
            trim_ch = @string_trim_ch(s[StrLen(s) - 1], ch);
        }
    }
}

class @string
{
    U0(*Append)
    (U8 * dst, U8 * fmt, ...);
    Bool (*BeginsWith)(U8* fragment, U8* str);
    Bool (*EndsWith)(U8* fragment, U8* str);
    Bool (*IsNumber)(U8* s);
    U8* (*Replace)(U8* s, U8* oldW, U8* newW);
    U8** (*Split)(U8* s, U8 ch = '\n', I64 * cnt);
    U0 (*Trim)(U8* s, U8 ch = NULL, I64 mode = TRIM_BOTH);
};

@string String;
String.Append = &@string_append;
String.BeginsWith = &@string_begins_with;
String.EndsWith = &@string_ends_with;
String.IsNumber = &@string_is_number;
String.Replace = &@string_replace;
String.Split = &@string_split;
String.Trim = &@string_trim;
