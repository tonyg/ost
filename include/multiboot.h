#ifndef Multiboot_H
#define Multiboot_H

#ifndef ASSEMBLY

typedef struct {
  u32 magic;
  u32 flags;
  u32 checksum;
  u32 header_addr;
  u32 load_addr;
  u32 load_end_addr;
  u32 bss_end_addr;
  u32 entry_addr;
  u32 mode_type;
  u32 width;
  u32 height;
  u32 depth;
} MultibootHeader;

typedef struct {
  u32 flags;
  u32 mem_lower;
  u32 mem_upper;
  u32 boot_device;
  void *cmdline_phys;
  u32 mods_count;
  void *mods_addr_phys;
  u32 syms[4];
  u32 mmap_length;
  void *mmap_addr_phys;
  u32 drives_length;
  void *drives_addr_phys;
  void *config_table_phys;
  void *boot_loader_name_phys;
  void *apm_table_phys;
  u32 vbe_control_info;
  u32 vbe_mode_info;
  u16 vbe_mode;
  u16 vbe_interface_seg;
  u16 vbe_interface_off;
  u16 vbe_interface_len;
} MultibootInfo;

typedef struct {
  u32 size;	/* size of entry, not including this size field. Used
		   to skip forward along the chain of entries. */
  u64 base;
  u64 length;
  u32 type;
} MultibootMemoryMapEntry;

typedef struct {
  void *mod_start_phys;
  void *mod_end_phys;
  void *string_phys;
  u32 reserved;
} MultibootModuleEntry;

#endif

#define MULTIBOOT_MAGIC 0x1BADB002

#define COMPUTE_MULTIBOOT_CHECKSUM(flags) (-(MULTIBOOT_MAGIC + (flags)))

/* Bits 0-15 specify "must-understand" requirements; bits 16-31
   specify optional requests. */
#define MULTIBOOT_HEADER_FLAG_PAGEALIGN_MODULES		0x00000001
#define MULTIBOOT_HEADER_FLAG_MEMORY_INFO		0x00000002
#define MULTIBOOT_HEADER_FLAG_VIDEO_INFO		0x00000004
#define MULTIBOOT_HEADER_FLAG_EXPLICIT_LOAD_ADDRESS	0x00010000

#define MULTIBOOT_MODE_TYPE_GRAPHICS			0
#define MULTIBOOT_MODE_TYPE_TEXT			1

#define MULTIBOOT_INFO_FLAG_MEMORY_INFO			0x00000001
#define MULTIBOOT_INFO_FLAG_BOOT_DEVICE			0x00000002
#define MULTIBOOT_INFO_FLAG_COMMAND_LINE		0x00000004
#define MULTIBOOT_INFO_FLAG_MODULES			0x00000008
#define MULTIBOOT_INFO_FLAG_AOUT_SYMTAB			0x00000010
#define MULTIBOOT_INFO_FLAG_ELF_SYMTAB			0x00000020
#define MULTIBOOT_INFO_FLAG_MMAP_PRESENT		0x00000040
#define MULTIBOOT_INFO_FLAG_DRIVES			0x00000080
#define MULTIBOOT_INFO_FLAG_CONFIG_TABLE		0x00000100
#define MULTIBOOT_INFO_FLAG_BOOT_LOADER_NAME		0x00000200
#define MULTIBOOT_INFO_FLAG_APM_TABLE			0x00000400
#define MULTIBOOT_INFO_FLAG_GRAPHICS_TABLE		0x00000800

#define MULTIBOOT_MEMORY_MAP_ENTRY_TYPE_RAM		0x00000001
/* all other values of MultibootMemoryMapEntry.type are reserved */

#endif
