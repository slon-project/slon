#define JSON_SAME -1
#define JSON_UNDEFINED 0
#define JSON_OBJECT 1
#define JSON_ARRAY 2
#define JSON_STRING 3
#define JSON_NUMBER 4
#define JSON_BOOLEAN 5
#define JSON_NULL 6
#define JSON_HTML 7

#define JSON_STATE_OBJECT_OR_ARRAY 0

#define JSON_STATE_OBJECT 100
#define JSON_STATE_OBJECT_KEY 101
#define JSON_STATE_OBJECT_SEPARATOR 102
#define JSON_STATE_OBJECT_TYPE 103
#define JSON_STATE_OBJECT_NEXT 104

#define JSON_STATE_OBJECT_OBJECT 105
#define JSON_STATE_OBJECT_ARRAY 106
#define JSON_STATE_OBJECT_STRING 107
#define JSON_STATE_OBJECT_NUMBER 108
#define JSON_STATE_OBJECT_BOOLEAN 109
#define JSON_STATE_OBJECT_NULL 110

#define JSON_STATE_ARRAY 200
#define JSON_STATE_ARRAY_TYPE 201
#define JSON_STATE_ARRAY_NEXT 202

#define JSON_STATE_ARRAY_OBJECT 203
#define JSON_STATE_ARRAY_ARRAY 204
#define JSON_STATE_ARRAY_STRING 205
#define JSON_STATE_ARRAY_NUMBER 206
#define JSON_STATE_ARRAY_BOOLEAN 207
#define JSON_STATE_ARRAY_NULL 208

#define JSON_PARSER_FIFO_SIZE 16384
#define JSON_STRINGIFY_BUF_SIZE 1048576

#define JSON_WRAPPER_MAGIC_NUMBER 0xDEADC0DEDEADC0DE

class @json_element
{
    @json_element* prev;
    @json_element* next;
    I64 type;
};

class @json_key : @json_element
{
    U8* name;
    U64 value;
};

class @json_item : @json_element { U64 value; };

class @json_object : @json_element
{
    I64 length;
    @json_key* keys;
};

class @json_array : @json_element
{
    I64 length;
    @json_item* items;
    @json_item* last_item;
};

extern class @json_callable_object;

class @json_callable_array : @json_array
{
    U64 (*@)(I64 index, Bool return_item = FALSE);
    @json_callable_array* (*a)(I64 index, Bool return_item = FALSE);
    @json_callable_object* (*o)(I64 index, Bool return_item = FALSE);
    U0 (*append)(@json_item* append_item);
    U0 (*insert)(@json_item* insert_item, I64 index);
    U0 (*prepend)(@json_item* prepend_item);
    U0 (*remove)(I64 index);
};

class @json_callable_object : @json_object
{
    U64 (*@)(U8* key, Bool return_key = FALSE);
    @json_callable_array* (*a)(U8* key, Bool return_key = FALSE);
    @json_callable_object* (*o)(U8* key, Bool return_key = FALSE);
    U0 (*set)(U8* key, U64 value, I64 type = JSON_SAME);
    U0 (*unset)(U8* key);
};

class @json_parser
{
    U8* stream;
    U8 token;
    CFifoU8* consumed;
    I64 pos;
    I64 state;
    Bool debug;
};

#define JsonArray @json_callable_array
#define JsonElement @json_element
#define JsonItem @json_item
#define JsonKey @json_key
#define JsonObject @json_callable_object

U0 @json_debug_parser_state(@json_parser* parser)
{
    switch (parser->state) {
    case JSON_STATE_OBJECT:
        "JSON_STATE_OBJECT\n";
        break;
    case JSON_STATE_OBJECT_KEY:
        "JSON_STATE_OBJECT_KEY\n";
        break;
    case JSON_STATE_OBJECT_SEPARATOR:
        "JSON_STATE_OBJECT_SEPARATOR\n";
        break;
    case JSON_STATE_OBJECT_TYPE:
        "JSON_STATE_OBJECT_TYPE\n";
        break;
    case JSON_STATE_OBJECT_NEXT:
        "JSON_STATE_OBJECT_NEXT\n";
        break;
    case JSON_STATE_OBJECT_STRING:
        "JSON_STATE_OBJECT_STRING\n";
        break;
    case JSON_STATE_OBJECT_NUMBER:
        "JSON_STATE_OBJECT_NUMBER\n";
        break;
    case JSON_STATE_ARRAY:
        "JSON_STATE_ARRAY\n";
        break;
    case JSON_STATE_ARRAY_TYPE:
        "JSON_STATE_ARRAY_TYPE\n";
        break;
    case JSON_STATE_ARRAY_NEXT:
        "JSON_STATE_ARRAY_NEXT\n";
        break;
    case JSON_STATE_ARRAY_STRING:
        "JSON_STATE_ARRAY_STRING\n";
        break;
    case JSON_STATE_ARRAY_NUMBER:
        "JSON_STATE_ARRAY_NUMBER\n";
        break;
    }
}

U0 @json_append_item(@json_array* arr, @json_item* append_item)
{
    if (!arr || !append_item)
        return;
    if (arr->type != JSON_ARRAY)
        return;
    @json_item* item = arr->last_item;
    if (!item) {
        append_item->prev = NULL;
        append_item->next = NULL;
        arr->items = append_item;
        arr->last_item = append_item;
        arr->length++;
        return;
    }
    item->next = append_item;
    append_item->prev = item;
    arr->last_item = append_item;
    arr->length++;
}

U8* @json_string_from_fifo(CFifoU8* f)
{
    U8 ch;
    I64 i = 0;
    U8* str = CAlloc(FifoU8Cnt(f) + 1, adam_task);
    while (FifoU8Cnt(f)) {
        FifoU8Rem(f, &ch);
        str[i] = ch;
        i++;
    }
    FifoU8Flush(f);
    return str;
}

U0 @json_insert_key(@json_object* obj, @json_key* key)
{
    if (!obj)
        return;
    if (!obj->keys) {
        obj->keys = key;
        obj->length++;
        return;
    }
    @json_key* k = obj->keys;
    while (k->next)
        k = k->next;
    k->next = key;
    key->prev = k;
    obj->length++;
}

U0 @json_rstrip(U8* str)
{
    if (!str || !StrLen(str))
        return;
    while (str[StrLen(str) - 1] == ' ' || str[StrLen(str) - 1] == '\r' || str[StrLen(str) - 1] == '\n' || str[StrLen(str) - 1] == '\t ')
        str[StrLen(str) - 1] = NULL;
}

extern @json_element* @json_parse_object_or_array(@json_parser* parser);

I64 @json_unescape_char(I64 escape_ch)
{
    I64 return_ch = escape_ch;

    // FIXME: unicode
    switch (escape_ch) {
    case 'b':
        return_ch = 0x08;
        break;
    case 'f':
        return_ch = 0x0c;
        break;
    case 'n':
        return_ch = 0x0a;
        break;
    case 'r':
        return_ch = 0x0d;
        break;
    case 't':
        return_ch = 0x09;
        break;
    default:
        break;
    }

    return return_ch;
}

U0 @json_parse_object(@json_parser* parser, @json_object* obj)
{
    @json_key* key = NULL;
    while (1) {
        switch (parser->stream[parser->pos]) {
        case '\\':
            if (parser->state == JSON_STATE_OBJECT_STRING)
                FifoU8Ins(parser->consumed, @json_unescape_char(parser->stream[++parser->pos]));
            break;
        case '}':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_NUMBER:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(key->value);
                key->value = Str2F64(key->value);
                @json_insert_key(obj, key);
                return;
                break;
            case JSON_STATE_OBJECT_BOOLEAN:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(key->value);
                if (StrCmp("true", key->value) && StrCmp("false", key->value)) {
                    PrintErr("@json_parse_object: Illegal boolean value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                if (!StrCmp("true", key->value))
                    key->value = TRUE;
                else
                    key->value = FALSE;
                @json_insert_key(obj, key);
                return;
                break;
            case JSON_STATE_OBJECT_NULL:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(key->value);
                if (StrCmp("null", key->value)) {
                    PrintErr("@json_parse_object: Illegal null value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                key->value = NULL;
                @json_insert_key(obj, key);
                return;
                break;
            case JSON_STATE_OBJECT:
            case JSON_STATE_OBJECT_NEXT:
                return;
                break;
            }
            break;
        case ',':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_NUMBER:
                key->value = @json_string_from_fifo(parser->consumed);
                key->value = Str2F64(key->value);
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT;
                break;
            case JSON_STATE_OBJECT_BOOLEAN:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(key->value);
                if (StrCmp("true", key->value) && StrCmp("false", key->value)) {
                    PrintErr("@json_parse_object: Illegal boolean value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                if (!StrCmp("true", key->value))
                    key->value = TRUE;
                else
                    key->value = FALSE;
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT;
                break;
            case JSON_STATE_OBJECT_NULL:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(key->value);
                if (StrCmp("null", key->value)) {
                    PrintErr("@json_parse_object: Illegal null value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                key->value = NULL;
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT;
                break;
            case JSON_STATE_OBJECT_NEXT:
                parser->state = JSON_STATE_OBJECT;
                break;
            }
            break;
        case ':':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_SEPARATOR:
                parser->state = JSON_STATE_OBJECT_TYPE;
                break;
            }
            break;
        case '[':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_ARRAY;
                key->value = @json_parse_object_or_array(parser);
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT_NEXT;
                break;
            }
            break;
        case '{':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_OBJECT;
                key->value = @json_parse_object_or_array(parser);
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT_NEXT;
                break;
            }
            break;
        case '"':
            switch (parser->state) {
            case JSON_STATE_OBJECT_STRING:
                key->value = @json_string_from_fifo(parser->consumed);
                @json_insert_key(obj, key);
                parser->state = JSON_STATE_OBJECT_NEXT;
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_STRING;
                parser->state = JSON_STATE_OBJECT_STRING;
                break;
            case JSON_STATE_OBJECT_KEY:
                key->name = @json_string_from_fifo(parser->consumed);
                parser->state = JSON_STATE_OBJECT_SEPARATOR;
                break;
            case JSON_STATE_OBJECT:
                key = CAlloc(sizeof(@json_key), adam_task);
                parser->state = JSON_STATE_OBJECT_KEY;
                break;
            }
            break;
        case '-':
        case '0' ... '9':
        case '.':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
            case JSON_STATE_OBJECT_NUMBER:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_NUMBER;
                parser->state = JSON_STATE_OBJECT_NUMBER;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        case 't':
        case 'f':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_BOOLEAN;
                parser->state = JSON_STATE_OBJECT_BOOLEAN;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        case 'n':
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                key->type = JSON_NULL;
                parser->state = JSON_STATE_OBJECT_NULL;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        default:
            switch (parser->state) {
            case JSON_STATE_OBJECT_KEY:
            case JSON_STATE_OBJECT_STRING:
            case JSON_STATE_OBJECT_BOOLEAN:
            case JSON_STATE_OBJECT_NULL:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        }
        if (parser->debug) {
            @json_debug_parser_state(parser);
            "Object: %08X, Pos: %d, Token: %c\n", obj, parser->pos,
                parser->stream[parser->pos];
            Sleep(50);
        }
        parser->pos++;
    }
}

U0 @json_parse_array(@json_parser* parser, @json_array* arr)
{
    @json_item* item = NULL;
    while (1) {
        if (parser->state == JSON_STATE_ARRAY) {
            switch (parser->stream[parser->pos]) {
            case 0:
                PrintErr("@json_parse_array: Malformed array");
                while (1)
                    Sleep(1);
                break;
            case ']':
                return;
                break;
            }
            item = CAlloc(sizeof(@json_item), adam_task);
            parser->state = JSON_STATE_ARRAY_TYPE;
        }
        switch (parser->stream[parser->pos]) {
        case '\\':
            if (parser->state == JSON_STATE_ARRAY_STRING)
                FifoU8Ins(parser->consumed, @json_unescape_char(parser->stream[++parser->pos]));
            break;
        case ']':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_NUMBER:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(item->value);
                item->value = Str2F64(item->value);
                @json_append_item(arr, item);
                return;
                break;
            case JSON_STATE_ARRAY_BOOLEAN:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(item->value);
                if (StrCmp("true", item->value) && StrCmp("false", item->value)) {
                    PrintErr("@json_parse_array: Illegal boolean value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                if (!StrCmp("true", item->value))
                    item->value = TRUE;
                else
                    item->value = FALSE;
                @json_append_item(arr, item);
                break;
            case JSON_STATE_ARRAY_NULL:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(item->value);
                if (StrCmp("null", item->value)) {
                    PrintErr("@json_parse_array: Illegal null value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                item->value = NULL;
                @json_append_item(arr, item);
                break;
            case JSON_STATE_ARRAY:
            case JSON_STATE_ARRAY_NEXT:
                return;
                break;
            }
            break;
        case ',':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_NUMBER:
                item->value = @json_string_from_fifo(parser->consumed);
                item->value = Str2F64(item->value);
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY;
                break;
            case JSON_STATE_ARRAY_BOOLEAN:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(item->value);
                if (StrCmp("true", item->value) && StrCmp("false", item->value)) {
                    PrintErr("@json_parse_array: Illegal boolean value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                if (!StrCmp("true", item->value))
                    item->value = TRUE;
                else
                    item->value = FALSE;
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY;
                break;
            case JSON_STATE_ARRAY_NULL:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_rstrip(item->value);
                if (StrCmp("null", item->value)) {
                    PrintErr("@json_parse_array: Illegal null value at position %d",
                        parser->pos);
                    while (1)
                        Sleep(1);
                }
                item->value = NULL;
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY;
                break;
            case JSON_STATE_ARRAY_NEXT:
                parser->state = JSON_STATE_ARRAY;
                break;
            }
            break;
        case '[':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_TYPE:
                item->type = JSON_ARRAY;
                item->value = @json_parse_object_or_array(parser);
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY_NEXT;
                break;
            }
            break;
        case '{':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_TYPE:
                item->type = JSON_OBJECT;
                item->value = @json_parse_object_or_array(parser);
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY_NEXT;
                break;
            }
            break;
        case '"':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                item->value = @json_string_from_fifo(parser->consumed);
                @json_append_item(arr, item);
                parser->state = JSON_STATE_ARRAY_NEXT;
                break;
            case JSON_STATE_ARRAY_TYPE:
                item->type = JSON_STRING;
                parser->state = JSON_STATE_ARRAY_STRING;
                break;
            }
            break;
        case '-':
        case '0' ... '9':
        case '.':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
            case JSON_STATE_ARRAY_NUMBER:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_TYPE:
                item->type = JSON_NUMBER;
                parser->state = JSON_STATE_ARRAY_NUMBER;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        case 't':
        case 'f':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_ARRAY_TYPE:
                item->type = JSON_BOOLEAN;
                parser->state = JSON_STATE_ARRAY_BOOLEAN;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        case 'n':
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            case JSON_STATE_OBJECT_TYPE:
                item->type = JSON_NULL;
                parser->state = JSON_STATE_ARRAY_NULL;
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        default:
            switch (parser->state) {
            case JSON_STATE_ARRAY_STRING:
            case JSON_STATE_ARRAY_BOOLEAN:
            case JSON_STATE_ARRAY_NULL:
                FifoU8Ins(parser->consumed, parser->stream[parser->pos]);
                break;
            }
            break;
        }
        if (parser->debug) {
            @json_debug_parser_state(parser);
            "Array: %08X, Pos: %d, Token: %c\n", arr, parser->pos,
                parser->stream[parser->pos];
            Sleep(50);
        }
        parser->pos++;
    }
}

extern @json_callable_array* @json_create_callable_array(@json_array* arr);
extern @json_callable_object* @json_create_callable_object(@json_object* obj);

@json_element* @json_parse_object_or_array(@json_parser* parser)
{
    @json_element* el = CAlloc(sizeof(@json_element) * 2, adam_task);
    while (1) {
        switch (parser->stream[parser->pos]) {
        case 0:
            return el;
            break;
        case ' ':
        case '\r':
        case '\n':
        case '\t':
            break;
        case '{':
            el->type = JSON_OBJECT;
            parser->pos++;
            parser->state = JSON_STATE_OBJECT;
            @json_parse_object(parser, el);
            return @json_create_callable_object(el);
            break;
        case '[':
            el->type = JSON_ARRAY;
            parser->pos++;
            parser->state = JSON_STATE_ARRAY;
            @json_parse_array(parser, el);
            return @json_create_callable_array(el);
            break;
        default:
            PrintErr("@json_parse_object_or_array: Invalid token: '%c'", parser->stream[parser->pos]);
            while (1) {
                Sleep(1);
            };
            break;
        }
        parser->pos++;
        Sleep(1);
    }
}

@json_element* @json_parse(U8* str)
{
    @json_parser* parser = CAlloc(sizeof(@json_parser), adam_task);
    parser->consumed = FifoU8New(JSON_PARSER_FIFO_SIZE, adam_task);
    // parser->debug = TRUE;
    parser->stream = str;
    @json_element* root = @json_parse_object_or_array(parser);
    FifoU8Flush(parser->consumed);
    FifoU8Del(parser->consumed);
    Free(parser);
    return root;
}

U0 @json_prepend_item(@json_array* arr, @json_item* prepend_item)
{
    if (!arr || !prepend_item)
        return;
    if (arr->type != JSON_ARRAY)
        return;
    @json_item* items = arr->items;
    arr->items = prepend_item;
    arr->items->next = items;
    arr->length++;
}

U0 @json_insert_item(@json_array* arr, @json_item* insert_item, I64 index)
{
    if (!arr || !insert_item)
        return;
    if (arr->type != JSON_ARRAY)
        return;
    if (index <= 0) {
        @json_prepend_item(arr, insert_item);
        return;
    }
    if (index >= arr->length) {
        @json_append_item(arr, insert_item);
        return;
    }
    @json_item* insert_at_item = arr->items;
    @json_item* insert_after_item = NULL;
    I64 i;
    for (i = 0; i < index; i++)
        insert_at_item = insert_at_item->next;
    insert_after_item = insert_at_item->prev;
    insert_after_item->next = insert_item;
    insert_item->prev = insert_after_item;
    insert_item->next = insert_at_item;
    insert_at_item->prev = insert_item;
    arr->length++;
}

U0 @json_stringify_append_char(U8* str, U8 char)
{
    // FIXME: unicode
    I64 len = StrLen(str);
    switch (char) {
    case '\\':
        str[len] = '\\';
        str[len + 1] = '\\';
        str[len + 2] = NULL;
        break;
    case 0x08:
        str[len] = '\\';
        str[len + 1] = 'b';
        str[len + 2] = NULL;
        break;
    case 0x0c:
        str[len] = '\\';
        str[len + 1] = 'f';
        str[len + 2] = NULL;
        break;
    case 0x0a:
        str[len] = '\\';
        str[len + 1] = 'n';
        str[len + 2] = NULL;
        break;
    case 0x0d:
        str[len] = '\\';
        str[len + 1] = 'r';
        str[len + 2] = NULL;
        break;
    case 0x09:
        str[len] = '\\';
        str[len + 1] = 't';
        str[len + 2] = NULL;
        break;
    default:
        str[len] = char;
        str[len + 1] = NULL;
        break;
    }
}

U0 @json_stringify_append_char_escape_quotes(U8* str, U8 char)
{
    // FIXME: unicode
    I64 len = StrLen(str);
    switch (char) {
    case '"':
        str[len] = '\\';
        str[len + 1] = '"';
        str[len + 2] = NULL;
        break;
    case '\\':
        str[len] = '\\';
        str[len + 1] = '\\';
        str[len + 2] = NULL;
        break;
    case 0x08:
        str[len] = '\\';
        str[len + 1] = 'b';
        str[len + 2] = NULL;
        break;
    case 0x0c:
        str[len] = '\\';
        str[len + 1] = 'f';
        str[len + 2] = NULL;
        break;
    case 0x0a:
        str[len] = '\\';
        str[len + 1] = 'n';
        str[len + 2] = NULL;
        break;
    case 0x0d:
        str[len] = '\\';
        str[len + 1] = 'r';
        str[len + 2] = NULL;
        break;
    case 0x09:
        str[len] = '\\';
        str[len + 1] = 't';
        str[len + 2] = NULL;
        break;
    default:
        str[len] = char;
        str[len + 1] = NULL;
        break;
    }
}

U0 @json_stringify_append_str(U8* str, U8* str2)
{
    while (*str2) {
        @json_stringify_append_char_escape_quotes(str, *str2);
        str2++;
    }
}

U0 @json_stringify_append_number(U8* str, F64 num)
{
    U8 buf[256];
    MemSet(buf, 0, 256);
    StrPrint(buf, "%.6f", num);
    I64 i = StrLen(buf) - 1;
    while (buf[i] == '0') {
        buf[i] = NULL;
        i--;
    }
    i = StrLen(buf) - 1;
    if (buf[i] == '.')
        buf[i] = NULL;
    @json_stringify_append_str(str, buf);
}

extern U0 @json_stringify_object_or_array(U8* str, @json_element* el);

U0 @json_stringify_object(U8* str, @json_object* obj)
{
    @json_stringify_append_char(str, '{');
    @json_key* key = obj->keys;
    while (key) {
        @json_stringify_append_char(str, '"');
        @json_stringify_append_str(str, key->name);
        @json_stringify_append_char(str, '"');
        @json_stringify_append_char(str, ':');
        switch (key->type) {
        case JSON_OBJECT:
        case JSON_ARRAY:
            @json_stringify_object_or_array(str, key->value);
            break;
        case JSON_STRING:
            @json_stringify_append_char(str, '"');
            @json_stringify_append_str(str, key->value);
            @json_stringify_append_char(str, '"');
            break;
        case JSON_NUMBER:
            @json_stringify_append_number(str, key->value);
            break;
        case JSON_BOOLEAN:
            @json_stringify_append_str(str, @t(key->value, "true", "false"));
            break;
        case JSON_NULL:
            @json_stringify_append_str(str, "null");
            break;
        default:
            PrintErr("@json_stringify_object: Invalid element type: %d", key->type);
            while (1) {
                Sleep(1);
            };
        }
        if (key->next)
            @json_stringify_append_char(str, ',');
        key = key->next;
    }
    @json_stringify_append_char(str, '}');
}

U0 @json_stringify_array(U8* str, @json_array* arr)
{
    @json_stringify_append_char(str, '[');
    @json_item* item = arr->items;
    while (item) {
        switch (item->type) {
        case JSON_OBJECT:
        case JSON_ARRAY:
            @json_stringify_object_or_array(str, item->value);
            break;
        case JSON_STRING:
            @json_stringify_append_char(str, '"');
            @json_stringify_append_str(str, item->value);
            @json_stringify_append_char(str, '"');
            break;
        case JSON_NUMBER:
            @json_stringify_append_number(str, item->value);
            break;
        case JSON_BOOLEAN:
            @json_stringify_append_str(str, @t(item->value, "true", "false"));
            break;
        case JSON_NULL:
            @json_stringify_append_str(str, "null");
            break;
        default:
            PrintErr("@json_stringify_array: Invalid element type: %d", item->type);
            while (1) {
                Sleep(1);
            };
        }
        if (item->next)
            @json_stringify_append_char(str, ',');
        item = item->next;
    }
    @json_stringify_append_char(str, ']');
}

U0 @json_stringify_object_or_array(U8* str, @json_element* el)
{
    while (el) {
        switch (el->type) {
        case JSON_OBJECT:
            @json_stringify_object(str, el);
            break;
        case JSON_ARRAY:
            @json_stringify_array(str, el);
            break;
        default:
            PrintErr("@json_stringify_object_or_array: Invalid element type: %d", el->type);
            while (1) {
                Sleep(1);
            };
            break;
        }
        el = el->next;
    }
}

U8* @json_stringify(@json_element* el, I64 buf_size = JSON_STRINGIFY_BUF_SIZE)
{
    U8* str = CAlloc(buf_size, adam_task);
    @json_stringify_object_or_array(str, el);
    return str;
}

U64 @json_get(@json_object* obj, U8* key, Bool return_key = FALSE)
{
    if (!obj || !key)
        return NULL;
    if (!obj->keys || obj->type != JSON_OBJECT)
        return NULL;
    @json_key* iter_key = obj->keys;
    while (iter_key) {
        if (!StrICmp(iter_key->name, key))
            if (return_key)
                return iter_key;
            else
                return iter_key->value;
        iter_key = iter_key->next;
    }
    return NULL;
}

U0 @json_set(@json_object* obj, U8* key, U64 value, I64 type = JSON_SAME)
{
    if (!obj || !key || !type)
        return;
    if (obj->type != JSON_OBJECT)
        return;
    @json_key* iter_key = obj->keys;
    while (iter_key) {
        if (!StrCmp(iter_key->name, key)) {
            if (type != JSON_SAME)
                iter_key->type = type;
            iter_key->value = value;
            return;
        }
        iter_key = iter_key->next;
    }
    @json_key* new_key = CAlloc(sizeof(@json_key), adam_task);
    new_key->name = StrNew(key, adam_task);
    new_key->type = type;
    if (new_key->type == JSON_STRING)
        new_key->value = StrNew(value, adam_task);
    else
        new_key->value = value;
    @json_insert_key(obj, new_key);
}

U0 @json_unset(@json_object* obj, U8* key)
{
    if (!obj || !key)
        return;
    if (obj->type != JSON_OBJECT)
        return;
    @json_key* iter_key = obj->keys;
    @json_key* prev_key = NULL;
    @json_key* next_key = NULL;
    while (iter_key) {
        if (!StrCmp(iter_key->name, key)) {
            prev_key = iter_key->prev;
            next_key = iter_key->next;
            if (prev_key)
                prev_key->next = next_key;
            if (next_key)
                next_key->prev = prev_key;
            // FIXME: Delete the unset key
            return;
        }
        iter_key = iter_key->next;
    }
}

U64 @json_callable_object_get_wrapper_function(U8* key, Bool return_key = FALSE)
{
    return @json_get(JSON_WRAPPER_MAGIC_NUMBER, key, return_key);
}

U0 @json_callable_object_set_wrapper_function(U8* key, U64 value, I64 type = JSON_SAME)
{
    @json_set(JSON_WRAPPER_MAGIC_NUMBER, key, value, type);
}

U0 @json_callable_object_unset_wrapper_function(U8* key)
{
    @json_unset(JSON_WRAPPER_MAGIC_NUMBER, key);
}

@json_callable_object* @json_create_callable_object(@json_object* obj)
{
    // Alloc callable object and copy instance
    @json_callable_object* cobj = CAlloc(sizeof(@json_callable_object), adam_task);
    MemCpy(cobj, obj, sizeof(@json_object));

    // Create a copy of function and patch Get
    U64 a;
    I64 code_size = MSize(&@json_callable_object_get_wrapper_function);
    cobj->@ = CAlloc(code_size, adam_task->code_heap);
    MemCpy(cobj->@, &@json_callable_object_get_wrapper_function, code_size);

    a = cobj->@;
    a += 0x13;
    MemSetI64(a, cobj, 1);

    a = cobj->@;
    a += 0x1c;
    @patch_call_rel32(a, &@json_get);

    // Create a copy of function and patch Set
    code_size = MSize(&@json_callable_object_set_wrapper_function);
    cobj->set = CAlloc(code_size, adam_task->code_heap);
    MemCpy(cobj->set, &@json_callable_object_set_wrapper_function, code_size);

    a = cobj->set;
    a += 0x1a;
    MemSetI64(a, cobj, 1);

    a = cobj->set;
    a += 0x23;
    @patch_call_rel32(a, &@json_set);

    // Create a copy of function and patch Unset
    code_size = MSize(&@json_callable_object_unset_wrapper_function);
    cobj->unset = CAlloc(code_size, adam_task->code_heap);
    MemCpy(cobj->unset, &@json_callable_object_unset_wrapper_function, code_size);

    a = cobj->unset;
    a += 0x0c;
    MemSetI64(a, cobj, 1);

    a = cobj->unset;
    a += 0x15;
    @patch_call_rel32(a, &@json_unset);

    cobj->a = cobj->@;
    cobj->o = cobj->@;

    return cobj;
}

@json_callable_object* @json_create_object()
{
    @json_object* obj = CAlloc(sizeof(@json_object), adam_task);
    obj->type = JSON_OBJECT;
    return @json_create_callable_object(obj);
}

@json_item* @json_create_item(U64 value, I64 type)
{
    @json_item* item = CAlloc(sizeof(@json_item), adam_task);
    item->type = type;
    if (item->type == JSON_STRING)
        item->value = StrNew(value, adam_task);
    else
        item->value = value;
    return item;
}

U64 @json_array_index(@json_array* arr, I64 index, Bool return_item = FALSE)
{
    if (!arr)
        return NULL;
    if (arr->type != JSON_ARRAY)
        return NULL;
    if (index < 0)
        return NULL;
    if (!arr->length)
        return NULL;
    if (index > 0 && index > arr->length - 1)
        return NULL;
    @json_item* item = arr->items;
    if (!item)
        return NULL;
    I64 i;
    for (i = 0; i < index; i++)
        item = item->next;
    if (return_item)
        return item;
    else
        return item->value;
}

U0 @json_remove_item(@json_array* arr, I64 index)
{
    if (!arr)
        return;
    if (arr->type != JSON_ARRAY)
        return;
    if (index < 0)
        return;
    if (!arr->length)
        return;
    if (index > 0 && index > arr->length - 1)
        return;
    @json_item* item = arr->items;
    if (!item)
        return;
    @json_item* prev_item = NULL;
    @json_item* next_item = NULL;
    I64 i;
    for (i = 0; i < index; i++)
        item = item->next;
    if (!index) {
        arr->items = item->next;
        goto @json_remove_item_final;
    }
    prev_item = item->prev;
    next_item = item->next;
    if (arr->last_item == item)
        arr->last_item = item->prev;
    prev_item->next = next_item;
    if (next_item)
        next_item->prev = prev_item;
    @json_remove_item_final : Free(item);
    --arr->length;
}

U64 @json_callable_array_index_wrapper_function(I64 index, Bool return_item = FALSE)
{
    return @json_get(JSON_WRAPPER_MAGIC_NUMBER, index, return_item);
}

U0 @json_callable_array_append_wrapper_function(@json_item* append_item)
{
    @json_append_item(JSON_WRAPPER_MAGIC_NUMBER, append_item);
}

U0 @json_callable_array_insert_wrapper_function(@json_item* insert_item, I64 index)
{
    @json_insert_item(JSON_WRAPPER_MAGIC_NUMBER, insert_item, index);
}

U0 @json_callable_array_prepend_wrapper_function(@json_item* prepend_item)
{
    @json_prepend_item(JSON_WRAPPER_MAGIC_NUMBER, prepend_item);
}

U0 @json_callable_array_remove_wrapper_function(I64 index)
{
    @json_remove_item(JSON_WRAPPER_MAGIC_NUMBER, index);
}

@json_callable_array* @json_create_callable_array(@json_array* arr)
{
    // Alloc callable object and copy instance
    @json_callable_array* carr = CAlloc(sizeof(@json_callable_array), adam_task);
    MemCpy(carr, arr, sizeof(@json_array));

    // Create a copy of function and patch Index
    U64 a;
    I64 code_size = MSize(&@json_callable_array_index_wrapper_function);
    carr->@ = CAlloc(code_size, adam_task->code_heap);
    MemCpy(carr->@, &@json_callable_array_index_wrapper_function, code_size);

    a = carr->@;
    a += 0x13;
    MemSetI64(a, carr, 1);

    a = carr->@;
    a += 0x1c;
    @patch_call_rel32(a, &@json_array_index);

    carr->a = carr->@;
    carr->o = carr->@;

    // Create a copy of function and patch Append
    code_size = MSize(&@json_callable_array_append_wrapper_function);
    carr->append = CAlloc(code_size, adam_task->code_heap);
    MemCpy(carr->append, &@json_callable_array_append_wrapper_function, code_size);

    a = carr->append;
    a += 0x0c;
    MemSetI64(a, carr, 1);

    a = carr->append;
    a += 0x15;
    @patch_call_rel32(a, &@json_append_item);

    // Create a copy of function and patch Prepend
    code_size = MSize(&@json_callable_array_prepend_wrapper_function);
    carr->prepend = CAlloc(code_size, adam_task->code_heap);
    MemCpy(carr->prepend, &@json_callable_array_prepend_wrapper_function, code_size);

    a = carr->prepend;
    a += 0x0c;
    MemSetI64(a, carr, 1);

    a = carr->prepend;
    a += 0x15;
    @patch_call_rel32(a, &@json_prepend_item);

    // Create a copy of function and patch Insert
    code_size = MSize(&@json_callable_array_insert_wrapper_function);
    carr->insert = CAlloc(code_size, adam_task->code_heap);
    MemCpy(carr->insert, &@json_callable_array_insert_wrapper_function, code_size);

    a = carr->insert;
    a += 0x12;
    MemSetI64(a, carr, 1);

    a = carr->insert;
    a += 0x1b;
    @patch_call_rel32(a, &@json_insert_item);

    // Create a copy of function and patch Remove
    code_size = MSize(&@json_callable_array_remove_wrapper_function);
    carr->remove = CAlloc(code_size, adam_task->code_heap);
    MemCpy(carr->remove, &@json_callable_array_remove_wrapper_function, code_size);

    a = carr->remove;
    a += 0x0c;
    MemSetI64(a, carr, 1);

    a = carr->remove;
    a += 0x15;
    @patch_call_rel32(a, &@json_remove_item);

    return carr;
}

@json_array* @json_create_array()
{
    @json_array* arr = CAlloc(sizeof(@json_array), adam_task);
    arr->type = JSON_ARRAY;
    return @json_create_callable_array(arr);
}

U64 @json_parse_file(U8* path)
{
    U64 res = NULL;
    U8* json_string = FileRead(path);
    if (json_string) {
        res = @json_parse(json_string);
        Free(json_string);
    }
    return res;
}

U0 @json_delete(@json_element* el)
{
    // FIXME: Implement this
    no_warn el;
}

U0 @json_dump_to_file(U8* path, @json_element* el)
{
    if (!path || !el)
        return;
    U8* json_string = @json_stringify(el);
    FileWrite(path, json_string, StrLen(json_string));
    Free(json_string);
}

@json_element* @json_clone(@json_element* el)
{
    if (!el)
        return NULL;
    U8* tmp = @json_stringify(el);
    if (!tmp)
        return NULL;
    @json_element* clone = @json_parse(tmp);
    Free(tmp);
    return clone;
}

class @json
{
    U0(*AppendItem)
    (@json_array * arr, @json_item * append_item);
    U64(*ArrayIndex)
    (@json_array * arr, I64 index, Bool return_item = FALSE);
    @json_element* (*Clone)(@json_element* el);
    @json_object* (*CreateObject)();
    @json_callable_object* (*CreateCallableObject)(@json_object* obj);
    @json_item* (*CreateItem)(U64 value, I64 type);
    @json_array* (*CreateArray)();
    U0 (*Delete)(@json_element* el);
    U0 (*DumpToFile)(U8* path, @json_element* el);
    U0(*InsertItem)
    (@json_array * arr, @json_item * insert_item, I64 index);
    @json_element* (*Parse)(U8* str);
    U64 (*ParseFile)(U8* path);
    U0(*PrependItem)
    (@json_array * arr, @json_item * prepend_item);
    U0(*RemoveItem)
    (@json_array * arr, I64 index);
    U64(*Get)
    (@json_object * obj, U8 * key, Bool return_key = FALSE);
    U0(*Set)
    (@json_object * obj, U8 * key, U64 value, I64 type);
    U8* (*Stringify)(@json_element* el, I64 buf_size = JSON_STRINGIFY_BUF_SIZE);
    U0(*Unset)
    (@json_object * obj, U8 * key);
};

@json Json;
Json.AppendItem = &@json_append_item;
Json.ArrayIndex = &@json_array_index;
Json.Clone = &@json_clone;
Json.CreateArray = &@json_create_array;
Json.CreateItem = &@json_create_item;
Json.CreateObject = &@json_create_object;
Json.Delete = &@json_delete;
Json.DumpToFile = &@json_dump_to_file;
Json.Get = &@json_get;
Json.InsertItem = &@json_insert_item;
Json.Parse = &@json_parse;
Json.ParseFile = &@json_parse_file;
Json.PrependItem = &@json_prepend_item;
Json.RemoveItem = &@json_remove_item;
Json.Set = &@json_set;
Json.Stringify = &@json_stringify;
Json.Unset = &@json_unset;
