;
; (C) 2008 Mike Brent aka Tursi aka HarmlessLion.com
; This software is provided AS-IS. No warranty
; express or implied is provided.
;
; This notice defines the entire license for this software.
; All rights not explicity granted here are reserved by the
; author.
;
; You may redistribute this software provided the original
; archive is UNCHANGED and a link back to my web page,
; http:;harmlesslion.com, is provided as the author's site.
; It is acceptable to link directly to a subpage at harmlesslion.com
; provided that page offers a URL for that purpose
;
; Source code, if available, is provided for educational purposes
; only. You are welcome to read it, learn from it, mock
; it, and hack it up - for your own use only.
;
; Please contact me before distributing derived works or
; ports so that we may work out terms. I don't mind people
; using my code but it's been outright stolen before. In all
; cases the code must maintain credit to the original author(s).
;
; Unless you have explicit written permission from me in advance,
; this code may never be used in any situation that changes these
; license terms. For instance, you may never include GPL code in
; this project because that will change all the code to be GPL.
; You may not remove these terms or any part of this comment
; block or text file from any derived work.
;
; -COMMERCIAL USE- Contact me first. I didn't make
; any money off it - why should you? ;) If you just learned
; something from this, then go ahead. If you just pinched
; a routine or two, let me know, I'll probably just ask
; for credit. If you want to derive a commercial tool
; or use large portions, we need to talk. ;)
;
; Commercial use means ANY distribution for payment, whether or
; not for profit.
;
; If this, itself, is a derived work from someone else's code,
; then their original copyrights and licenses are left intact
; and in full force.
;
; http//harmlesslion.com - visit the web page for contact info
;
	.include "jaguar.inc"

	.text
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.extern	start_GPU		; address in program space to copy from
	.extern first_GPU		; address in GPU space to copy to
	.extern	end_GPU			; last address in GPU space
	.extern	runGPU			; address to start execution at

	.extern	UpdateList

	.extern	a_vdb
	.extern	a_vde
	.extern	a_hdb
	.extern	a_hde
	.extern	width
	.extern	height

	.extern	gSetOLP
	.extern	olp2set
	
	.extern MYJOY
	.extern animbuffer

	.globl InitVBint

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This is where we get control after the startup code...
_start::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copy over the GPU program
	move.l	#first_GPU,a0	; Get the address of the GPU code
	move.l	#start_GPU,a1	; Get destination address
	move.l	#end_GPU,d0		; and calculate length of GPU code
	sub.l	#start_GPU,d0
	asr.l	#2,d0			; divide by 4 since we're copying longs
.loop:
	move.l	(a0)+,(a1)+		; actually copy the code...
	dbra	d0,.loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copy the palette into the chip

	move.l	#256,d0
	move.l	#CLUT,a0
	move.l	#PALETTE,a1

.cloop:
	move.w	(a1)+,(a0)+
	dbra	d0,.cloop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Now set the proper Vmode...

	move.w	#$6c7,VMODE	; Set 16 bit RGB; 300-320? overscanned
	
	; $6c7
	; 1000 1100 0001
	;              1 - Video Enable
	;            11  - Mode: 16 bit RGB
	;           0    - Genlock (disabled)
	;         0      - INCEN (Genlock switching)
	;        0       - Local border when INCEN enabled
	;       1        - CSync enabled
	;      1         - Clear line buffer to background register after display (16 bit only)
	;    0           - VARMOD (disabled)
	; 011            - Pixel width in clocks (this value + 1)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Starts the GPU, halts 68k and never returns
	move.l	#0,G_FLAGS		; Make sure the GPU starts in a good state
	move.l	#runGPU,G_PC	; GPU Program counter set
	move.l	#$1,G_CTRL		; Set the GPU going

	move.l #$FFFFFFFF,MYJOY	; clear joystick 
	
.forevr:
	stop #$2000				; Goodbye, cruel 68K world.  :(
	
	move.w #$81fe,JOYSTICK	; enable read, audio, nothing on joystick 1, col 0 on joystick 0
	move.l JOYSTICK,d0		; by doing a long read, we get JOYSTICK and JOYBUTS
	move.l	d0,MYJOY		; set joystick
	
	bra .forevr				; vblank can wake us up, go back to sleep

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: InitVBint 
; Install our vertical blank handler and enable interrupts
;
InitVBint:
		move.l	d0,-(sp)
		
		move.w	INT1,d0			; Disable video interrupts
		andi.w	#$fffe,d0
		move.w	d0,INT1

		move.l	#UpdateList,LEVEL0	; Install 68K LEVEL0 handler

		move.w	a_vde,d0		; Must be ODD
		ori.w	#1,d0
		move.w	d0,VI

		move.w	INT1,d0			; Enable video interrupts
		ori.w	#1,d0
		move.w	d0,INT1

		move.w	sr,d0
		and.w	#$F8FF,d0		; Lower 68k IPL to allow
		move.w	d0,sr			; interrupts

		move.l	(sp)+,d0
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Data
 
	.68000
	.data

	.long
PALETTE::
.include "pal.inc"
	.long
CLEFT::
.include "cleft.inc"
	.long
CRIGHT::
.include "cright.inc"
	.long
SLEFT::
.include "sleft.inc"
	.long
SRIGHT::
.include "sright.inc"
	.long
WLEFT01::
.include "wleft01.inc"
	.long
WLEFT02::
.include "wleft02.inc"
	.long
WLEFT03::
.include "wleft03.inc"
	.long
WLEFT04::
.include "wleft04.inc"
	.long
WLEFT05::
.include "wleft05.inc"
	.long
WLEFT06::
.include "wleft06.inc"
	.long
WLEFT07::
.include "wleft07.inc"
	.long
WLEFT08::
.include "wleft08.inc"
	.long
WLEFT09::
.include "wleft09.inc"
	.long
WLEFT10::
.include "wleft10.inc"
	.long
WLEFT11::
.include "wleft11.inc"
	.long
WLEFT12::
.include "wleft12.inc"
	.long
WLEFT13::
.include "wleft13.inc"
	.long
WLEFT14::
.include "wleft14.inc"
	.long
WLEFT15::
.include "wleft15.inc"
	.long
WLEFT16::
.include "wleft16.inc"
	.long
WLEFT17::
.include "wleft17.inc"
	.long
WLEFT18::
.include "wleft18.inc"
	.long
WLEFT19::
.include "wleft19.inc"
	.long
WLEFT20::
.include "wleft20.inc"
	.long
WLEFT21::
.include "wleft21.inc"
	.long
WLEFT22::
.include "wleft22.inc"
	.long
WLEFT23::
.include "wleft23.inc"
	.long
WLEFT24::
.include "wleft24.inc"
	.long
WRIGHT01::
.include "wright01.inc"
	.long
WRIGHT02::
.include "wright02.inc"
	.long
WRIGHT03::
.include "wright03.inc"
	.long
WRIGHT04::
.include "wright04.inc"
	.long
WRIGHT05::
.include "wright05.inc"
	.long
WRIGHT06::
.include "wright06.inc"
	.long
WRIGHT07::
.include "wright07.inc"
	.long
WRIGHT08::
.include "wright08.inc"
	.long
WRIGHT09::
.include "wright09.inc"
	.long
WRIGHT10::
.include "wright10.inc"
	.long
WRIGHT11::
.include "wright11.inc"
	.long
WRIGHT12::
.include "wright12.inc"
	.long
WRIGHT13::
.include "wright13.inc"
	.long
WRIGHT14::
.include "wright14.inc"
	.long
WRIGHT15::
.include "wright15.inc"
	.long
WRIGHT16::
.include "wright16.inc"
	.long
WRIGHT17::
.include "wright17.inc"
	.long
WRIGHT18::
.include "wright18.inc"
	.long
WRIGHT19::
.include "wright19.inc"
	.long
WRIGHT20::
.include "wright20.inc"
	.long
WRIGHT21::
.include "wright21.inc"
	.long
WRIGHT22::
.include "wright22.inc"
	.long
WRIGHT23::
.include "wright23.inc"
	.long
WRIGHT24::
.include "wright24.inc"

; animations: first frame is a keyframe, loop on zero
	.long
ANIMWLEFT::
	; loop at WLEFT02
	dc.l	SLEFT,WLEFT01,WLEFT02,WLEFT03,WLEFT04,WLEFT05,WLEFT06
	dc.l	WLEFT07,WLEFT08,WLEFT09,WLEFT10,WLEFT11,WLEFT12,WLEFT13
	dc.l	WLEFT14,WLEFT15,WLEFT16,WLEFT17,WLEFT18,WLEFT19,WLEFT20
	dc.l	WLEFT21,WLEFT22,WLEFT23,WLEFT24,0
ANIMWRIGHT::
	; loop at WRIGHT02
	dc.l	SRIGHT,WRIGHT01,WRIGHT02,WRIGHT03,WRIGHT04,WRIGHT05,WRIGHT06
	dc.l	WRIGHT07,WRIGHT08,WRIGHT09,WRIGHT10,WRIGHT11,WRIGHT12,WRIGHT13
	dc.l	WRIGHT14,WRIGHT15,WRIGHT16,WRIGHT17,WRIGHT18,WRIGHT19,WRIGHT20
	dc.l	WRIGHT21,WRIGHT22,WRIGHT23,WRIGHT24,0
ANIMCLEFT::
	dc.l	CLEFT,0
ANIMCRIGHT::
	dc.l	CRIGHT,0
ANIMSLEFT::
	dc.l	SLEFT,0
ANIMSRIGHT::
	dc.l	SRIGHT,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		