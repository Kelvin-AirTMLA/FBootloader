# FBL

A from-scratch **x86_64 operating system** written in NASM assembly and C. The project boots on bare metal via a custom BIOS bootloader, transitions through real mode → protected mode → long mode, and is designed to load a 64-bit kernel at `0x10000`.

This is a systems programming project focused on low-level hardware interaction, memory management, and OS fundamentals — not a Linux userspace application.

---

## Project scope

### What this project is

FBL is an educational/research bootloader targeting the **x86_64 PC platform**. It follows the classic boot chain used by real operating systems:

1. **BIOS** loads a 512-byte MBR at `0x7C00`
2. **Stage 1** (`boot.asm`) reads Stage 2 from disk via INT 0x13 LBA
3. **Stage 2** (`stage2.asm`) enables the A20 line, loads the kernel, builds page tables, and enters **64-bit long mode**
4. **Kernel** (in progress) takes over at physical `0x10000`

The goal is a minimal but real OS: interrupt handling, memory management, basic drivers (VGA, serial, keyboard, timer), and eventually a small C kernel.

### What is implemented today


| Component                | Status     | Description                                        |
| ------------------------ | ---------- | -------------------------------------------------- |
| Stage 1 MBR bootloader   | ✅ Done     | LBA disk read, BIOS print, boot signature          |
| Stage 2 bootloader       | ✅ Done     | A20, unreal mode, kernel load, GDT, PAE, long mode |
| Support modules          | ✅ Done     | `print`, `disk`, `a20`, `gdt`                      |
| Shared header / macros   | ✅ Done     | Constants, syscall ABI helpers, GDT/IDT flags      |
| Build system             | ✅ Done     | Makefile, `disk.img` assembly, QEMU run target     |
| Docker dev environment   | ✅ Done     | Cross-compile toolchain (NASM, GRUB, xorriso)      |
| 64-bit kernel            | 🚧 Planned | Entry point and driver stubs scaffolded            |
| Interrupts (IDT/PIC)     | 🚧 Planned | File structure in place                            |
| Memory manager (PMM/VMM) | 🚧 Planned | File structure in place                            |
| Device drivers           | 🚧 Planned | VGA, serial, keyboard, timer stubs                 |


### What is out of scope (for now)

- Multitasking / user processes
- File systems
- Networking
- GUI / windowing
- POSIX compatibility

These may come later; the current focus is a **working boot chain and minimal kernel**.

---

## Architecture

```
BIOS
 └── boot.asm (Stage 1, MBR @ 0x7C00)
      └── stage2.asm (@ 0x7E00)
           ├── Enable A20
           ├── Load kernel from disk (LBA 17+)
           ├── Identity-mapped page tables (2 MB huge page)
           ├── 32-bit protected mode
           └── 64-bit long mode
                └── kernel @ 0x10000 (in progress)
```

**Memory layout (boot-time)**


| Address         | Usage                          |
| --------------- | ------------------------------ |
| `0x7C00`        | Stage 1 MBR                    |
| `0x7E00`        | Stage 2                        |
| `0x1000–0x4000` | Page tables (PML4 / PDPT / PD) |
| `0x10000`       | Kernel load address            |
| `0xB8000`       | VGA text framebuffer (planned) |


---

## Tech stack

- **NASM** — assembly (bootloader + low-level kernel code)
- **GCC cross-compiler** — C kernel (via Docker / dockcross)
- **QEMU** — emulation and testing
- **Make** — build orchestration
- **Docker** — reproducible build environment on macOS (Apple Silicon → `linux/amd64`)

---

## Project structure

```
os/
├── Makefile                          # Build boot.bin, stage2.bin, disk.img
├── FBL/
│   ├── build/                        # Output: boot.bin, stage2.bin, disk.img
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
│       └── kernel/                   # Kernel (in progress)
│           ├── kernel_entry.asm
│           ├── kernel.c
│           ├── hdd_drivers/          # VGA, serial, keyboard, timer
│           ├── interrupts/           # IDT, PIC, ISR stubs
│           ├── memory/               # Paging, PMM, VMM
│           └── utilities/            # I/O, strings
```

---

## Build and run

### Prerequisites (native)

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

Output:

- `FBL/build/boot.bin` — 512-byte MBR
- `FBL/build/stage2.bin` — Stage 2 loader
- `FBL/build/disk.img` — bootable disk image

### Run in QEMU

```bash
make run
```

You should see BIOS text output: `Loading Stage 2...` → `OK` → Stage 2 messages.

### Docker dev environment (macOS / cross-compile)

```bash
cd FBL/my_build
docker build -t ficcrunchos-env .
docker run --rm -it --platform linux/amd64 \
  -v "$(pwd)/..":/root/env ficcrunchos-env
```

Inside the container, build from the mounted project root with `make`.

---

## Roadmap

- [ ] Minimal kernel entry (print `"FicCrunchOS"` to VGA)
- [ ] Wire `kernel.bin` into `disk.img` at LBA 17
- [ ] IDT + PIC setup, CPU exception handlers
- [ ] Physical memory manager (bitmap allocator)
- [ ] Virtual memory / higher-half kernel
- [ ] Serial and keyboard drivers
- [ ] PIT timer for preemption groundwork

---

## License

TBD — add a license before publishing publicly if you plan to open-source.

---

