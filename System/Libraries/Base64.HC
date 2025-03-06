
U8* @base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

U8* @base64_decode(U8* input, I64* output_length)
{
    I64 input_length = StrLen(input);
    if (input_length % 4 != 0) {
        return NULL; // Invalid Base64 input length
    }

    // Calculate the expected output length
    *output_length = (3 * input_length) / 4;
    if (input[input_length - 1] == '=') {
        (*output_length)--;
    }
    if (input[input_length - 2] == '=') {
        (*output_length)--;
    }

    // Allocate memory for the decoded data
    U8* decoded_data = CAlloc(*output_length, slon_mem_task);
    if (decoded_data == NULL) {
        return NULL; // Memory allocation failed
    }

    // Initialize variables for decoding process
    I32 i, j = 0;
    U32 sextet_bits = 0;
    I64 sextet_count = 0;
    U32 base64_value;
    U8* char_pointer;
    U8 input_find_buf[2];
    input_find_buf[1] = NULL;

    // Loop through the Base64 input and decode it
    for (i = 0; i < input_length; i++) {
        // Convert Base64 character to a 6-bit value
        base64_value = 0;
        if (input[i] == '=') {
            base64_value = 0;
        } else {
            input_find_buf[0] = input[i];
            char_pointer = StrFirstOcc(@base64_chars, input_find_buf);
            if (char_pointer == NULL) {
                Free(decoded_data);
                return NULL; // Invalid Base64 character
            }
            base64_value = char_pointer - @base64_chars;
        }

        // Combine 6-bit values into a 24-bit sextet
        sextet_bits = (sextet_bits << 6) | base64_value;
        sextet_count++;

        // When a sextet is complete, decode it into three bytes
        if (sextet_count == 4) {
            decoded_data[j++] = (sextet_bits >> 16) & 0xFF;
            decoded_data[j++] = (sextet_bits >> 8) & 0xFF;
            decoded_data[j++] = sextet_bits & 0xFF;
            sextet_bits = 0;
            sextet_count = 0;
        }
    }

    return decoded_data;
}

U8* @base64_encode(U8* input, I64 input_length)
{
    I64 i;
    U8 buf[3];
    I64 c = 0;
    U8* output = CAlloc(input_length * 2, slon_mem_task);

    for (i = 0; i < input_length; i += 3) {
        buf[0] = input[i];
        buf[1] = @t((i + 1 < input_length), input[i + 1], 0);
        buf[2] = @t((i + 2 < input_length), input[i + 2], 0);

        output[c++] = @base64_chars[(buf[0] & 0xfc) >> 2];
        output[c++] = @base64_chars[((buf[0] & 0x03) << 4) + ((buf[1] & 0xf0) >> 4)];
        output[c++] = @t((i + 1 < input_length), @base64_chars[((buf[1] & 0x0f) << 2) + ((buf[2] & 0xc0) >> 6)], '=');
        output[c++] = @t((i + 2 < input_length), @base64_chars[buf[2] & 0x3f], '=');
    }

    output[c] = '\0';
    return output;
}
