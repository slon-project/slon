unsigned long ioport_read_u8(unsigned short address) { return 0; }

unsigned long ioport_read_u16(unsigned short address) { return 0; }

unsigned long ioport_read_u32(unsigned short address) { return 0; }

void ioport_write_u8(unsigned short address, unsigned char value) { }

void ioport_write_u16(unsigned short address, unsigned short value) { }

void ioport_write_u32(unsigned short address, unsigned int value) { }

bool os_blink(char const* frequency_as_string) { return 0; }

unsigned long os_call(unsigned long function_name, unsigned long arg) { return 0; }

unsigned int os_device_calloc(unsigned int size) { return 0; }

void os_exit() { }

char const* os_file_picker(char const* path, char const* glob) { return 0; }

char const* os_files_list(char const* path) { return 0; }

bool os_is_vm() { return 0; }

bool os_path_exists(char const* path) { return 0; }

void os_pc_speaker(char const* frequency_as_string) { }

unsigned long os_random() { return 0; }

unsigned long os_read_entire_file(char const* filename, long* size)
{
    return 0;
}

void os_screenshot() { }

char const* os_to_uppercase(char const* input_string) { return 0; }

void os_write_entire_file(char const* filename, unsigned char* buffer,
    long size) { }

long pci_find(long class_code) { return 0; }

unsigned long pci_read_u8(long bus, long device, long fun, long offset)
{
    return 0;
}

unsigned long pci_read_u16(long bus, long device, long fun, long offset)
{
    return 0;
}

unsigned long pci_read_u32(long bus, long device, long fun, long offset)
{
    return 0;
}

void pci_write_u8(long bus, long device, long fun, long offset,
    unsigned char value) { }

void pci_write_u16(long bus, long device, long fun, long offset,
    unsigned short value) { }

void pci_write_u32(long bus, long device, long fun, long offset,
    unsigned int value) { }

void time_busy(long duration) { }

long time_jiffies() { return 0; }

long time_now() { return 0; }

void time_sleep(long duration) { }