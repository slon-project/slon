# slon
A Mastodon-compatible fediverse server for TempleOS

![slon](https://slon-project.org/images/slon.png)

## overview

Slon is developed to run from a standard TempleOS installation, or directly from the live CD.

Slon includes its own Virtio net and block device drivers, TCP/IPv4 network stack, and various supplemental libraries, all loaded at runtime, making it suitable for QEMU/KVM based cloud environments.

Image uploads powered by [Catbox](https://catbox.moe) (Support Catbox: [Patreon](https://patreon.com/catbox) | [Ko-fi](https://ko-fi.com/catboxmoe) | [Merch](https://store.catbox.moe))

Slon utilizes the following third-party libraries:

- [`stb_image.h`](https://github.com/nothings/stb/blob/master/stb_image.h) and [`stb_image_write.h`](https://github.com/nothings/stb/blob/master/stb_image_write.h) (for optional image processing)

- [`libtomcrypt`](https://github.com/libtom/libtomcrypt) and [`tlse`](https://github.com/eduardsui/tlse) (for HTTP Signatures and TLS support)

Slon has a default theme for web view that mimics the TempleOS WinMgr, using emoji from the [SerenityOS](https://serenityos.org) project (https://emoji.serenityos.org):

![slon-web-preview](https://slon-project.org/images/slon-web-preview.gif)

Slon is intended to be deployed as a single-user (or, handful-of-users) instance. 

## build

#### dependencies: 

- clang-format
- gcc
- [isoc-py3](https://github.com/alec3660/isoc-py3)
- [jakt](https://github.com/serenityos/jakt)
- moreutils
- qemu
- [templeos-slipstream](https://github.com/alec3660/templeos-slipstream)
- TempleOS V5.03 Standard Distro ISO
  
  sha256sum: 5d0fc944e5d89c155c0fc17c148646715bc1db6fa5750c0b913772cfec19ba26

#### create an empty disk image for storage:

- `qemu-img create -f qcow2 virtio-disk.qcow2 4G`

#### build and run

- modify `scripts/build_all` to match your system

- (optional) use the included `.vscode` workflow

## links 

- https://slon-project.org

- https://discord.gg/qT3HfmG7GG