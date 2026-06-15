# FBL — F Bootloader

A from-scratch **x86_64 BIOS bootloader** written in NASM. FBL boots on bare metal, reads a second stage from disk, enables the A20 line, sets up paging, and transitions from real mode → protected mode → **64-bit long mode** — ready to hand off to a kernel at `0x10000`.

This is a systems programming project focused on the boot chain and low-level x86_64 bring-up, not a full operating system.

---

## What this project is

FBL is an educational bootloader for the **x86_64 PC platform**. It implements the classic two-stage BIOS boot process:

1. **BIOS** loads a 512-byte MBR at `0x7C00`
2. **Stage 1** (`boot.asm`) reads Stage 2 from disk via INT 0x13 LBA
3. **Stage 2** (`stage2.asm`) enables A20, loads a kernel image from disk, builds page tables, and enters long mode

The bootloader is the deliverable. A separate kernel (C + assembly stubs are scaffolded under `kernel/`) is planned as follow-on work.

---

## What is implemented


| Component              | Status | Description                                        |
| ---------------------- | ------ | -------------------------------------------------- |
| Stage 1 MBR bootloader | ✅ Done | LBA disk read, BIOS print, boot signature          |
| Stage 2 bootloader     | ✅ Done | A20, kernel load, GDT, PAE, paging, long mode      |
| Support modules        | ✅ Done | `print`, `disk`, `a20`, `gdt`                      |
| Shared header / macros | ✅ Done | Constants, segment flags, boot-time addresses      |
| Build system           | ✅ Done | Makefile, `disk.img` assembly, QEMU run target     |
| Docker dev environment | ✅ Done | Cross-compile toolchain (NASM, GRUB, xorriso)      |
| Kernel handoff         | 🚧 Next | Load and jump to `kernel.bin` at `0x10000`         |

---

## Boot flow

```
BIOS
 └── boot.asm (Stage 1, MBR @ 0x7C00)
      └── stage2.asm (@ 0x7E00)
           ├── Enable A20
           ├── Load kernel from disk (LBA 17+)
           ├── Identity-mapped page tables (2 MB huge page)
           ├── Enter 32-bit protected mode
           └── Enter 64-bit long mode → jump to kernel @ 0x10000
```

**Memory layout (boot-time)**


| Address         | Usage                          |
| --------------- | ------------------------------ |
| `0x7C00`        | Stage 1 MBR                    |
| `0x7E00`        | Stage 2                        |
| `0x1000–0x4000` | Page tables (PML4 / PDPT / PD) |
| `0x10000`       | Kernel load address            |

---

## Tech stack

- **NASM** — bootloader assembly
- **QEMU** — emulation and testing
- **Make** — build orchestration
- **Docker** — reproducible dev environment on macOS (Apple Silicon → `linux/amd64`)

---

## Project structure

```
os/
├── Makefile                          # Build boot.bin, stage2.bin, disk.img
├── FBL/
│   ├── build/                        # Output (gitignored): boot.bin, stage2.bin, disk.img
│   ├── my_build/
│   │   └── Dockerfile                # Cross-compile dev container
│   └── src/impl/x86_64/boot/
│       ├── boot.asm                  # Stage 1 MBR
│       ├── stage2.asm                # Stage 2: A20, paging, long mode
│       ├── header.asm                # Shared constants and macros
│       ├── support/
│       │   ├── print.asm             # BIOS INT 0x10 output
│       │   ├── disk.asm              # INT 0x13 LBA read
│       │   ├── a20.asm               # A20 line enable
│       │   └── gdt.asm               # 32/64-bit GDT
│       └── kernel/                   # Kernel stubs (not part of bootloader build yet)
```

---

## Build and run

### Prerequisites

- `nasm`
- `make`
- `dd` (standard on macOS/Linux)
- `qemu-system-x86_64` (optional, for `make run`)

### Build

```bash
git clone <your-repo-url>
cd os
make
```

Output (written to `FBL/build/`, not tracked in git):

- `boot.bin` — 512-byte MBR
- `stage2.bin` — Stage 2 loader
- `disk.img` — bootable disk image

### Run in QEMU

```bash
make run
```

You should see BIOS text output: `Loading Stage 2...` → `OK` → Stage 2 messages.

### Docker dev environment (macOS / cross-compile)

```bash
cd FBL/my_build
docker build -t fbl-env .
docker run --rm -it --platform linux/amd64 \
  -v "$(pwd)/..":/root/env fbl-env
```

Inside the container, build from the mounted project root with `make`.

---

## Roadmap

- [ ] Wire `kernel.bin` into `disk.img` at LBA 17
- [ ] Verify clean handoff to kernel entry at `0x10000`
- [ ] Error handling for disk read failures
- [ ] Multiboot2 or boot info structure for the kernel

---

## License

TBD — add a license before publishing publicly if you plan to open-source.
