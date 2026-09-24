/* SPDX-License-Identifier: BSD-2-Clause-Patent */

/* Bootshimming for LK! 
 * This is a hack, Because some android devices
 * (shitty devices) require a ARM64 kernel header
 * Which is unable to be provided in base LK,
 * This in order adds the ability to 
 * boot LK in second stage
 */

#define SHIM_PAD 0x100

/* Text Offset, fun */
#define TEXT_OFFSET 0x80000

/* Test optimization code, if causing issues comment it out */
#define TEST 1

.globl _Head
_Head:
 adr x4, _Payload  /* x4 = where the payload landed */
 b _Start

/* arm64 "Image" header (see Documentation/arm64/booting.rst),
 * This header makes the initial bootloader think that its booting
 * a normal ARM64 kernel, whilst its booting whatever the fuck
 * i want it to boot (permitting it doesnt violate TZ.
 * Mu silicium does this on the kona platform iirc, i dont
 * give a fuck so like lets do this tremendous hack on LK
 * instead 
 */

 .quad TEXT_OFFSET  /* 0x08: text_offset */
 .quad FD_SIZE + SHIM_PAD /* 0x10: image_size (whole blob) */
 .quad 0   /* 0x18: flags */
 .quad 0   /* 0x20: res2 */
#ifdef DTB_OFFSET
 .long 0   /* 0x28: res5 (kept 0) */
 .long DTB_OFFSET  /* 0x2c: appended DTB offset */
#else
 .quad 0   /* 0x28: res5 */
#endif
 .quad 0   /* 0x30: res4 */
 .byte 'A', 'R', 'M', 0x64 /* 0x38: magic "ARM\x64" */
 .long 0   /* 0x3c: res5 */

_Start:
 /* x0-x3 hold the boot args (x2 = DTB) and must reach the payload
  * untouched, so the copy uses x4-x9 only. */
 mov x5, x4  /* x5 = source (payload actual addr) */

/* Load from memory, oh and lets try a optimization */
#ifdef TEST
 adrp x6, FD_BASE
 add x6, x6 :lo12:FD_BASE
#else
 ldr x6, =FD_BASE  /* x6 = destination */
#endif
 cmp x5, x6
 beq _Entry   /* already at the link address */

 ldr x7, =FD_SIZE  /* x7 = byte count */
_CopyLoop:
 ldp x8, x9, [x5], #16
 stp x8, x9, [x6], #16
 subs x7, x7, #16
 b.ne _CopyLoop

 /* sync caches before the jump */
.function sync
 dsb ish
 ic iallu
 isb
 ldr x6, =FD_BASE
.end

_Entry:
 br x6   /* x0-x3 preserved for the payload */

 .ltorg

 .align 4
 .org SHIM_PAD
_Payload:
