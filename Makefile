# =============================================================================
# Makefile — Bootloader Build
# Assembles boot.asm and stage2.asm into a combined bootable disk image.
#
# Requirements: nasm, dd, qemu-system-x86_64 (optional for testing)
#
# Targets:
#   make          → build disk.img
#   make run      → launch in QEMU
#   make clean    → remove build artefacts
# =============================================================================

NASM        := nasm
BOOT_DIR    := FBL/src/impl/x86_64/boot
SUPPORT_DIR := $(BOOT_DIR)/support
BUILD_DIR   := FBL/build
NASM_FLAGS  := -f bin -I $(BOOT_DIR)/ -I $(SUPPORT_DIR)/

BOOT_SRC    := $(BOOT_DIR)/boot.asm
STAGE2_SRC  := $(BOOT_DIR)/stage2.asm
HEADER_ASM  := $(BOOT_DIR)/header.asm
PRINT_ASM   := $(SUPPORT_DIR)/print.asm
DISK_ASM    := $(SUPPORT_DIR)/disk.asm
A20_ASM     := $(SUPPORT_DIR)/a20.asm
GDT_ASM     := $(SUPPORT_DIR)/gdt.asm

BOOT_BIN    := $(BUILD_DIR)/boot.bin
STAGE2_BIN  := $(BUILD_DIR)/stage2.bin
DISK_IMG    := $(BUILD_DIR)/disk.img

# Disk image size in 512-byte sectors (2880 = 1.44 MB floppy equivalent)
DISK_SECTORS := 2880

.PHONY: all run clean

all: $(DISK_IMG)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): $(BOOT_SRC) $(HEADER_ASM) $(PRINT_ASM) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@
	@size=$$(wc -c < $@); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: boot.bin is $$size bytes, must be exactly 512!"; exit 1; \
	fi
	@echo "  [OK] boot.bin (512 bytes)"

$(STAGE2_BIN): $(STAGE2_SRC) $(HEADER_ASM) $(PRINT_ASM) $(DISK_ASM) $(A20_ASM) $(GDT_ASM) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@
	@echo "  [OK] stage2.bin ($$(wc -c < $@) bytes)"

$(DISK_IMG): $(BOOT_BIN) $(STAGE2_BIN) | $(BUILD_DIR)
	dd if=/dev/zero of=$@ bs=512 count=$(DISK_SECTORS) 2>/dev/null
	dd if=$(BOOT_BIN) of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	dd if=$(STAGE2_BIN) of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	@echo "  [OK] $(DISK_IMG) built"

run: $(DISK_IMG)
	qemu-system-x86_64 \
		-drive file=$(DISK_IMG),format=raw,index=0,media=disk \
		-m 128M \
		-no-reboot \
		-serial stdio \
		-d int,cpu_reset 2>/dev/null || \
	qemu-system-x86_64 \
		-drive file=$(DISK_IMG),format=raw,index=0,media=disk \
		-m 128M \
		-no-reboot

clean:
	rm -rf $(BUILD_DIR)
	@echo "  [OK] cleaned"
