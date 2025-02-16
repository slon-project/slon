/* clang-format off */

DocMax(adam_task);
WinMax(adam_task);
WinToTop(adam_task);

#include "Setup/Environment";
#include "Drivers/Virtio-blk";

// FFI support files
#include "FFI/Base";
#include "FFI/LibC";
#include "FFI/New";
#include "FFI/ELF64";

// stb_image library
#include "Utilities/Image";
load_elf("M:/build/bin/image");

// Jakt support files
#include "Jakt/OS";
#include "Jakt/IOPort";
#include "Jakt/PCI";
#include "Jakt/Time";

#include "Libraries/Tlse";
load_elf("M:/build/bin/tlse");

// Networking APIs
#include "Api/Dns.HC";
#include "Api/Icmp.HC";
#include "Api/Ipv4.HC";
#include "Api/MD5.HC";
#include "Api/NetInfo.HC";
#include "Api/Tcp.HC";
#include "Api/Tls.HC";

// Libraries
#include "Libraries/Base64";
#include "Libraries/Json";
#include "Libraries/Rsa";
#include "Libraries/Sha256";
#include "Libraries/String";
#include "Libraries/Http";

load_elf("M:/build/bin/net");

// Networking Utilities
#include "Utilities/Dns";
#include "Utilities/NetRep";
#include "Utilities/Ping";
#include "Utilities/Time";

Spawn(_start, , "Net Task");

/* clang-format on */
