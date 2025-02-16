struct virtio_queue_buf {
    u64 address;
    u32 length;
    u16 flags;
    u16 next;
};
struct virtio_avail {
    u16 flags;
    u16 index;
    u16 ring[256];
    u16 int_index;
};
struct virtio_used_item {
    u32 index;
    u32 length;
};
struct virtio_used {
    u16 flags;
    u16 index;
    virtio_used_item ring[256];
    u16 int_index;
};
struct virtio_queue {
    virtio_queue_buf buffers[256];
    virtio_avail available;
    u8 padding[3578];
    virtio_used used;
};