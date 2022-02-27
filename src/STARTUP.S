;-----------------------------------------------------------------------------
; Warning!!! Warning!!! Warning!!! Warning!!! Warning!!! Warning!!! Warning!!!
; Warning!!! Warning!!! Warning!!! Warning!!! Warning!!! Warning!!! Warning!!!
;-----------------------------------------------------------------------------
; Do not change any of the code in this file except where explicitly noted.
; Making other changes can cause your program's startup code to be incorrect.
;-----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; Jaguar Development System Source Code
; Copyright (c)1995 Atari Corp.
; ALL RIGHTS RESERVED
;
; Module: startup.s - Hardware initialization/License screen display
;
; Revision History:
;  1/12/95 - SDS: Modified from MOU.COF sources.
;  2/28/95 - SDS: Optimized some code from MOU.COF.
;  3/14/95 - SDS: Old code preserved old value from INT1 and OR'ed the
;                 video interrupt enable bit. Trouble is that could cause
;                 pending interrupts to persist. Now it just stuffs the value.
;  4/17/95 - MF:  Moved definitions relating to startup picture's size and
;                 filename to top of file, separate from everything else (so
;                 it's easier to swap in different pictures).
;----------------------------------------------------------------------------
; Program Description:
; Jaguar Startup Code
;
; Steps are as follows:
; 1. Set GPU/DSP to Big-Endian mode
; 2. Set VI to $FFFF to disable video-refresh.
; 3. Initialize a stack pointer to high ram.
; 3.5 Zero out the BSS segment
; 4. Initialize video registers.
; 5. Create the object list 
; 6. Install interrupt handler, configure VI, enable video interrupts,
;    lower 68k IPL to allow interrupts. 
; 7. Use GPU routine to stuff OLP with pointer to object list.
; 8. Turn on video.
; 9. Jump to _start.
;
; Notes:
; All video variables are exposed for program use. gSetOLP and olp2set
; are exposed so they don't need to be included by exterior code again.
;-----------------------------------------------------------------------------

	.include	"jaguar.inc"
	
; Globals
		.globl	gSetOLP
		.globl	olp2set

		.globl  a_vdb
		.globl  a_vde
		.globl  a_hdb
		.globl  a_hde
		.globl  width
		.globl  height
; Externals
		.extern	_start
		.extern InitLister
		.extern InitVBint

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Program Entry Point Follows...

		.text

		move.l  #$70007,G_END		; big-endian mode
		move.l  #$70007,D_END
		move.w  #$FFFF,VI       	; disable video interrupts

		move.l  #INITSTACK,a7   	; Setup a stack

		jsr 	InitVideo      		; Setup our video registers.
		jsr 	InitLister     		; Initialize Object Display List
		jsr 	InitVBint      		; Initialize our VBLANK routine

		move.l  d0,olp2set      	; D0 is swapped OLP from InitLister
		move.l  #gSetOLP,G_PC   	; Set GPU PC
		move.l  #RISCGO,G_CTRL  	; Go!
waitforset:
		move.l  G_CTRL,d0   		; Wait for write.
		andi.l  #$1,d0
		bne 	waitforset

		move.w  #$AC7,VMODE     	; Configure Video

	    jmp 	_start				; Jump to main code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: gSetOLP
;            Use the GPU to set the OLP and quit.
;
;    Inputs: olp2set - Variable contains pre-swapped value to stuff OLP with.
;
; NOTE!!!: This code can run in DRAM only because it contains no JUMP's or
;          JR's. It will generate a warning with current versions of MADMAC
;          because it doesn't '.ORG'.
;
		.long
		.gpu
gSetOLP:
		movei   #olp2set,r0   		; Read value to write
		load    (r0),r1

		movei   #OLP,r0       		; Store it
		store   r1,(r0)

		moveq   #0,r0         		; Stop GPU
		movei   #G_CTRL,r1
		store   r0,(r1)
		nop             			; Two "feet" on the brake pedal
		nop

		.68000
		.bss
		.long

olp2set:    	.ds.l   1           		; GPU Code Parameter

		.text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: InitVideo (same as in vidinit.s)
;            Build values for hdb, hde, vdb, and vde and store them.
;
						
InitVideo:
		movem.l d0-d6,-(sp)
			
		move.w  CONFIG,d0      		 ; Also is joystick register
		andi.w  #VIDTYPE,d0    		 ; 0 = PAL, 1 = NTSC
		beq 	palvals

		move.w  #NTSC_HMID,d2
		move.w  #NTSC_WIDTH,d0

		move.w  #NTSC_VMID,d6
		move.w  #NTSC_HEIGHT,d4

		bra 	calc_vals
palvals:
		move.w  #PAL_HMID,d2
		move.w  #PAL_WIDTH,d0

		move.w  #PAL_VMID,d6
		move.w  #PAL_HEIGHT,d4

calc_vals:
		move.w  d0,width
		move.w  d4,height

		move.w  d0,d1
		asr 	#1,d1         	 	; Width/2

		sub.w   d1,d2         	  	; Mid - Width/2
		add.w   #4,d2         	  	; (Mid - Width/2)+4

		sub.w   #1,d1         	  	; Width/2 - 1
		ori.w   #$400,d1      	  	; (Width/2 - 1)|$400
		
		move.w  d1,a_hde
		move.w  d1,HDE

		move.w  d2,a_hdb
		move.w  d2,HDB1
		move.w  d2,HDB2

		move.w  d6,d5
		sub.w   d4,d5
		move.w  d5,a_vdb

		add.w   d4,d6
		move.w  d6,a_vde

		move.w  a_vdb,VDB
		move.w  #$FFFF,VDE

		move.w  #$AC1,VMODE
			
		move.l  #0,BORD1        	; Black border
		move.w  #0,BG           	; Init line buffer to black
			
		movem.l (sp)+,d0-d6
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		.data
		.phrase

		.bss
		.dphrase

a_hdb:  		.ds.w   1
a_hde:      	.ds.w   1
a_vdb:      	.ds.w   1
a_vde:      	.ds.w   1
width:      	.ds.w   1
height:     	.ds.w   1

		.end

