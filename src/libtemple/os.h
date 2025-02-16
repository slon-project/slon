bool os_blink(char const* frequency_as_string);
unsigned long os_call(unsigned long function_name, unsigned long arg);
unsigned int os_device_calloc(unsigned int size);
void os_exit();
char const* os_file_picker(char const* path, char const* glob);
char const* os_files_list(char const* path);
bool os_is_vm();
bool os_path_exists(char const* path);
void os_pc_speaker(char const* frequency_as_string);
unsigned long os_random();
u8* os_read_entire_file(char const* filename, i64* size);
void os_screenshot();
char const* os_to_uppercase(char const* input_string);
void os_write_entire_file(char const* filename, unsigned char* buffer,
    i64 size);