long pci_find(long class_code);
unsigned long pci_read_u8(long bus, long device, long fun, long offset);
unsigned long pci_read_u16(long bus, long device, long fun, long offset);
unsigned long pci_read_u32(long bus, long device, long fun, long offset);
void pci_write_u8(long bus, long device, long fun, long offset,
    unsigned char value);
void pci_write_u16(long bus, long device, long fun, long offset,
    unsigned short value);
void pci_write_u32(long bus, long device, long fun, long offset,
    unsigned int value);