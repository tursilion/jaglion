; Heavily modified by Tursi http://harmlesslion.com
;
; Jaguar Example Source Code
; Jaguar Workshop Series #1
; Copyright (c)1994 Atari Corp.
; ALL RIGHTS RESERVED
;
; Program: mou.cof      - Minimum time object list update
;  Module: mou_list.s   - Object List Refresh and Initialization

		.include    "jaguar.inc"

		.globl      InitLister
		.globl		UpdateList
		.globl		main_obj_list

		.extern     a_vde
		.extern     a_vdb
		.extern     a_hdb
		.extern     a_hde
		.extern		width
		.extern		height
		.extern		ANIMWLEFT
		.extern		ANIMWRIGHT
		.extern		ANIMSLEFT
		.extern		ANIMSRIGHT
		.extern		ANIMCLEFT
		.extern		ANIMCRIGHT
		.extern		gpudraw
		.extern		keyframe
		.extern		start_GPU
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; list stuff from mou example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PPP			.equ	8				; Pixels per Phrase (8-bit)

; 80x100x8-bit
BMP_WIDTH	.equ	80				; Width in Pixels 
BMP_IWIDTH  .equ    (80/PPP)		; Width in Phrases to draw
BMP_HEIGHT	.equ	100				; Height in Pixels

BMP_DWIDTH	.equ	(80/PPP)		; Width in Phrases for data
BMP_LINES	.equ	(BMP_HEIGHT*2)	; Height in Half Scanlines

BITMAP_OFF1	.equ	(6*8)			; Offset to the first word of the bitmap (for updates)

LISTSIZE	.equ	10				; List size in phrases

ANIMSPEED	.equ	4				; vblanks per anim frame (should be 4 for 15fps)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		.text

; InitLister: Initialize Object List Processor List
;
;    Returns: Pre-word-swapped address of current object list in d0.l
;
;  Registers: d1.l/d0.l - Phrase being built
;             d2.l      - Address of STOP object in destination buffer
;             d3.l      - Calculation register
;             d4.l      - Width of image in phrases
;             d5.l      - Height of image in scanlines
;             a0.l      - Roving object list pointer
		
InitLister:
		movem.l d1-d5/a0,-(sp)		; Save registers

		; initialize animations variables
		move.l	#ANIMWRIGHT,leoframe
		move.l	#ANIMWRIGHT+8,leoloop
		move.l	#ANIMSPEED,animcnt
		move.l	#1,keyframe			; first frame is keyframe (sets non-zero, gpu will clear)
		move.l	#0,gpudraw			; no data set yet

		; build list
		lea     main_obj_list,a0
		move.l	a0,d2				; Copy

; Write a stop object first (so we don't have to calculate its address)
; d2 already contains this address
		clr.l   d1
		move.l  #(STOPOBJ),d0

		move.l  d1,(a0)+                
		move.l  d0,(a0)+

; qphrase align with 3 more useless stops
		move.l  d1,(a0)+                
		move.l  d0,(a0)+

		move.l  d1,(a0)+                
		move.l  d0,(a0)+

		move.l  d1,(a0)+                
		move.l  d0,(a0)+

; Write first BRANCH object (branch if YPOS > a_vde )

		clr.l   d1
		move.l  #(BRANCHOBJ|O_BRLT),d0	; $4000 = VC < YPOS
		jsr     format_link             ; Stuff in our LINK address
						
		move.w  a_vde,d3                ; for YPOS
		lsl.w   #3,d3                   ; Make it bits 13-3
		or.w    d3,d0

		move.l  d1,(a0)+                                
		move.l  d0,(a0)+                ; First OBJ is done.

; Write second branch object (branch if YPOS < a_vdb)   
; Note: LINK address is the same so preserve it
		andi.l  #$FF000007,d0           ; Mask off CC and YPOS
		ori.l   #O_BRGT,d0				; $8000 = VC > YPOS
		move.w  a_vdb,d3                ; for YPOS
		lsl.w   #3,d3                   ; Make it bits 13-3
		or.w    d3,d0

		move.l  d1,(a0)+                ; Second OBJ is done
		move.l  d0,(a0)+        

; Write a standard 80x100x8 BITMAP (must be dword aligned!) object ; Note: color 0 is transparent!
		clr.l   d1
		clr.l   d0                      ; Type = BITOBJ

		move.l  a0,d2					; jump address is next object	; why does the BMP obj have a link address?
		add.l   #24,d2          
		jsr     format_link

		move.l  #BMP_HEIGHT,d5			; Height of image
		lsl.l   #8,d5					; HEIGHT
		lsl.l   #6,d5
		or.l    d5,d0

		move.w  height,d3         		; Center bitmap vertically
		sub.w   #BMP_HEIGHT,d3
		add.w   a_vdb,d3
		andi.w  #$FFFE,d3               ; Must be even

		lsl.w   #3,d3
		or.w    d3,d0                   ; Stuff YPOS in low phrase

		move.l  #animbuffer,d3			; address of sprite
		andi.l  #$FFFFF8,d3				; 21 bits of data - note old example code only had 20 (beta hardware!)
		lsl.l   #8,d3                   ; Shift bitmap_addr into position
		or.l    d3,d1
     
		move.l  d1,(a0)+
		move.l	d1,bmp_highl
		move.l  d0,(a0)+
		move.l	d0,bmp_lowl

		move.l  #O_TRANS,d1             ; Now for PHRASE 2 of BITOBJ
		move.l  #O_DEPTH8|O_NOGAP,d0	; Bit Depth = 8-bit, Contiguous data

		move.w	width,d3				; Get width in clocks
		lsr.w	#2,d3					; /4 Pixel Divisor
		sub.w   #BMP_WIDTH,d3
		lsr.w   #1,d3
		andi	#$fff,d3				; only 12 bits
		or.w    d3,d0

		move.l  #BMP_DWIDTH,d4 
		lsl.l   #8,d4                   ; DWIDTH
		lsl.l   #8,d4
		lsl.l   #2,d4
		or.l    d4,d0

		move.l	#BMP_IWIDTH,d4
		move.l  d4,d3                   ; Copy for below
		lsl.l   #8,d4                   
		lsl.l   #8,d4
		lsl.l   #8,d4                   ; IWIDTH Bits 28-31
		lsl.l   #4,d4
		or.l    d4,d0

		lsr.l   #4,d3                   ; IWIDTH Bits 37-32
		or.l    d3,d1

		move.l  d1,(a0)+                ; Write second PHRASE of BITOBJ
		move.l  d0,(a0)+

; Write a STOP object at end of list
		clr.l   d1
		move.l  #(STOPOBJ),d0

		move.l  d1,(a0)+                
		move.l  d0,(a0)+

; Now return swapped list pointer in D0                      
		move.l	#main_obj_list+32,d0		; skip the initial stops
		swap    d0

		movem.l (sp)+,d1-d5/a0
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: format_link
;
;    Inputs: d1.l/d0.l is a 64-bit phrase
;            d2.l contains the LINK address to put into bits 42-24 of phrase
;
;   Returns: Updated phrase in d1.l/d0.l

format_link:
		movem.l d2-d3,-(sp)

		andi.l  #$3FFFF8,d2             ; Ensure alignment/valid address
		move.l  d2,d3                   ; Make a copy

		swap	d2                   	; Put bits 10-3 in bits 31-24
		clr.w	d2
		lsl.l   #5,d2
		or.l    d2,d0

		lsr.l   #8,d3                   ; Put bits 21-11 in bits 42-32
		lsr.l   #3,d3
		or.l    d3,d1

		movem.l (sp)+,d2-d3             ; Restore regs
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; UpdateList: Update list fields destroyed by the object processor.
;			  and do other vblank stuff
;
;  Registers:	a0.l      - General Purpose Pointer
;				d0,d1,d2  - used in joystick read

UpdateList:
		movem.l	d0-d2/a0,-(sp)
		
		; Update OP list - must be done before the first Bitmap is processed
		move.l	#main_obj_list+BITMAP_OFF1,a0
		move.l	bmp_highl,(a0)		; Phrase = d1.l/d0.l
		move.l	bmp_lowl,4(a0)
		
		; while we're here, let's just read the joystick real quick and update registers accordingly
		; bits end up a bit screwy. It looks like these. The first set is joystick 1 if enabled,
		; notice how it's selects are the opposite to joystick 0. Value to write is $81YZ, where Y
		; is the row for JOY1 and Z is the row for JOY0. The 8 enables read, and the 1 enables
		; audio (why that's in the joystick register... oi.). I can't test the Numpad or option
		; because my Genesis pad doesn't have those. ;)
		;           JOY1JOY0                       J1J0
		; row0 (e): 369#RLDU xxxxxxxx xxxxxxxx xxxxOxAP
		; row1 (d): 2580*741 xxxxxxxx xxxxxxxx xxxxCxBx		; note: numpad may be backwards here
		; row2 (b): *7412580 xxxxxxxx xxxxxxxx xxxxBxCx
		; row3 (7): RLDU369# xxxxxxxx xxxxxxxx xxxxAPOx		; also, option may be bitshifted by one :)

;		move.w #$81fe,JOYSTICK	; enable read, audio, nothing on joystick 1, col 0 on joystick 0
;		move.l JOYSTICK,d0		; by doing a long read, we get JOYSTICK and JOYBUTS
		move.l	MYJOY,d0

		btst #26,d0					; left
		bne .joy3
		cmp.l #ANIMWLEFT+8,leoloop
		beq .joy6					; already walking left
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMWLEFT,leoframe	; walk left anim sequence
		move.l #ANIMWLEFT+8,leoloop	; loop on the third frame
		bra .joy6
		
.joy3:	
		btst #27,d0					; right
		bne .joy1
		cmp.l #ANIMWRIGHT+8,leoloop
		beq .joy6					; already walking right
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMWRIGHT,leoframe	; walk right anim sequence
		move.l #ANIMWRIGHT+8,leoloop	; loop on the third frame
		bra .joy6

.joy1:
		btst #25,d0					; down
		bne .joy2
		; switch to crouch needed only if we are currently standing or walking
		move.l leoloop,d0
		cmp.l #ANIMWLEFT+8,d0
		beq .cleft
		cmp.l #ANIMSLEFT,d0
		beq .cleft
		cmp.l #ANIMWRIGHT+8,d0
		beq .cright
		cmp.l #ANIMSRIGHT,d0
		beq .cright
		; none of the above
		bra .joy6
.cleft:
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMCLEFT,leoframe	; crouch left
		move.l #ANIMCLEFT,leoloop	; loop on the third frame
		bra .joy6
.cright:
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMCRIGHT,leoframe	; crouch right
		move.l #ANIMCRIGHT,leoloop	; loop on the third frame
		bra .joy6
				
.joy2:	; no direction we care about is pressed, so just stand there
		; work out which way to stand (if we already are we don't need to do anything)
		move.l leoloop,d0
		cmp.l #ANIMWLEFT+8,d0
		beq .sleft
		cmp.l #ANIMCLEFT,d0
		beq .sleft
		cmp.l #ANIMWRIGHT+8,d0
		beq .sright
		cmp.l #ANIMCRIGHT,d0
		beq .sright
		; none of the above
		bra .joy6
.sleft:
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMSLEFT,leoframe	; crouch left
		move.l #ANIMSLEFT,leoloop	; loop on the third frame
		bra .joy6
.sright:
		move.l d0,keyframe			; any non-zero value to trigger next keyframe
		move.l #ANIMSRIGHT,leoframe	; crouch right
		move.l #ANIMSRIGHT,leoloop	; loop on the third frame
		bra .joy6
.joy6:
		
		; check animation speed
		subq.l	#1,animcnt
		bne .noanimatall
		move.l	#ANIMSPEED,animcnt

.newframe:				
		; GPU work - tell it the sprite(s) to update
		; and where to update them from (eventually move this so it just
		; processes the animation list itself).
		move.l leoframe,a0			; get pointer into list
		move.l (a0),d2				; read value from table into d1
		move.l d2,gpudraw			; write that value to the gpu

		; Interrupt the GPU so it can do VSYNC stuff
		move.l	G_CTRL,d1
		or.l	#4,d1
		move.l	d1,G_CTRL
		
		; now increment our animation cycle
		addq #4,a0
		cmp.l #0,(a0)
		bne .noanimloop
		move.l leoloop,a0
.noanimloop:
		move.l a0,leoframe
		
.noanimatall:		

		; Signal we're done
		move.w	#$101,INT1
		move.w	#$0,INT2

		movem.l	(sp)+,d0-d2/a0
		rte

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Storage space for our object lists
		.bss
; I never use this. I don't know why I need it. But if I don't have it, then
; a few objects shift in memory and suddenly the program doesn't work. I'm
; sure it's dumb but I don't have time.  PUT NOTHING ELSE BEFORE THE OP LIST
my_objlist:
	.ds.l	16

		.dphrase			
bmp_highl:
		.ds.l		1
bmp_lowl:
		.ds.l		1
leoframe:
		.ds.l		1
leoloop:
		.ds.l		1
animcnt:
		.ds.l		1

; The list must start 4-phrase aligned (or more??)
; WARNING: it sometimes looks like qphrase only does a dphrase alignment!
; Putting -rq on aln seems to have helped (it was -rd before)
; I still don't get the alignment on this fucking OP list. Works, doesn't work,
; on alignment, off alignment.. whatever. Why is it so damn picky?
		.qphrase
main_obj_list:
		.ds.b       LISTSIZE*8

; buffer for the animated sprite
		.phrase
animbuffer::
		.ds.b		8008
		
		.long
MYJOY::
		.ds.l	1

		.end
