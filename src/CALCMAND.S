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

.include	'jaguar.inc'

ISTACK		.equ	$F03EFC			; Location of GPU interrupt stack (why is this below top of RAM?)

	.extern animbuffer

; Register usage
; r0	Zero
; r1	Work
; r2	Work
; r3	Work
; r4	Work	
; r5	
; r6	
; R7  - 64 - used for the horizon calculation
; R8  - Address of main wait loop
; r9	
; r10	
; r11	byte out count for decompression loop
; r12	current dword out for decompression loop
; r13	dword count in decompression loop
; r14	current dword in decompression loop
; r15	255 for horizon code and decompression
; r16	1984 for horizon code (saturated blue)
; R17 - Horizon line
; R18 - Mask value for VC
; r19	
; R20 - VC register address
; R21 - BG Reg
; R22	address of decode function
; R23	address of keyframe register
; r24	old VC
; r25	address of exitint
; r26	address of output buffer
; r27	address of gpudraw register
; r28	interrupt use
; r29	interrupt use
; r30	interrupt corrupts
; r31	interrupt stack

	.gpu

first_GPU::
	.org	G_RAM	; start of GPU RAM
start_GPU::

; cpu interrupt here
cpuint0:
	;storew r16,(r21)			; force BG to blue to avoid flicker during decompression.
	storew r0,(r21)				; See also see gradient code. (Flicker is pretty minimal,
								; but the sprite is huge and takes more than VBLANK to unpack)
	
	; load a count for the clearing loop below (moved here to make the jr fit over the unroll)
	movei #250,r3				; 250*4*8=8000 bytes

	; as long as we don't want any other interrupts, we can put our code here
	load (r23),r2				; get keyframe reg
	load (r27),r1				; get the address of the data to decompress
	cmp r2,r0					; test if keyframe is set
	; (stall)
	jr EQ,.noclear				; 0, so skip clearing
	move r26,r2					; delay slot - load output address
	
	; we are just writing blanks - for now hard code 80*100 0 bytes,
	; which is 80*100/4 0 dwords ;) Don't touch R1 in here
	; we write 64-bit words, we'll also unroll the loop a bit to help speed
	; (stall)
	move r2,r4					; reduce stalling in unroll loop
	store r0,(r23)				; clear the keyframe flag (only valid for one frame)
	addq #8,r4					; offset from r2 by 8 bytes
.bllp:
	storep r0,(r2)				; This was crashing before because it was overwriting the end of the OPL
	addqt #16,r2
	storep r0,(r4)
	addqt #16,r4
	storep r0,(r2)
	addqt #16,r2
	subq #1,r3					; count down
	storep r0,(r4)				; doesn't affect flags
	jr NZ,.bllp					; flags are ready, no waiting
	addqt #16,r4				; delay slot, whether we jump or not
	
.noclear:
	cmp r1,r0					; check if data is NULL
	; (stall)
	jump EQ,(r25)				; if yes, exit
	move r26,r2					; delay slot - reload the write address again in case we need to continue

	; 32 bit memory access (working fine, though no visible performance gain. Less bus activity is good though?)
outerdecode::
	; this is where we access external memory 32-bits at a time
	load (r1),r14				; current word
	moveq #5,r13				; bytes left to process + 1
	rorq #24,r14				; get first data into lsb
	addq #4,r1					; increment source address
	
decode:
	; so we read a byte. If it is $00, we are done. If it is greater than $80, then
	; it is a count of NULs to skip. If it is less, then a stream of data follows
	subq #1,r13					; see if we are done
	move r14,r3					; copy current to work register (doesn't affect flags)
	jr EQ,outerdecode			; need to get another word
	and r15,r3					; delay slot, only used if we don't branch - mask off LS Byte to work on

	rorq #24,r14				; rotate work register (otherwise we stall)
		
	cmp r3,r0					; test for zero byte
	jump EQ,(r25)				; if count finished, exit
	btst #7,r3					; check high bit of byte (delay slot, happens either way, but we only care if we didn't branch)

	jr EQ,notpacked				; branch to handle a run of data
	bclr #7,r3					; don't want the high bit any more (delay slot again, but ok both ways)
	
	; here we are skipping unchanged code, so just add r3 to r2
	jump (r22)					; all done, get next byte
	add r3,r2					; delay slot, always used

	; here we are running a run of data, so we just copy r3 bytes from the data
	; 32 bit reads - works fine	though no visible performance gain
	; This only accesses external RAM 32-bits at a time, but it still takes the data apart
	; and then puts it back together before sending. To do it most efficiently
	; would take a lot of code - you need to take into account the current position
	; in r14, the alignment of the destination data, etc.
cpylpouter:
	; this is where we access external memory 32-bits at a time (copy of above code)
	load (r1),r14				; current word
	moveq #5,r13				; bytes left to process + 1
	rorq #24,r14				; get first data into lsb
	addq #4,r1					; increment source address

; enters here from above, skips outer loop
notpacked:	
	subq #1,r13					; decrement bytes left
	move r14,r4					; get data byte (doesn't affect flags)
	jr EQ,cpylpouter			; need to get another word
	and r15,r4					; delay slot, only used if we don't branch - mask it

	rorq #24,r14				; rotate data for next pass

	; single byte write block
	; writing 32-bits, with alignment and stuff, is tricky. So far no love.
	; probably will not see performance gain here either, and should be in vblank, so it's okay
	subq #1,r3
	storeb r4,(r2)				; single byte write eats bus 
	jr NZ,notpacked
	addq #1,r2					; delay slot

	jump (r22)					; and we're done, fetch the next byte
	nop
	
exitint:
	; finished interrupt, clean up
	movei #G_FLAGS,r30
	load (r30),r29				; read flags
	bclr #3,r29					; clear IMASK
	bset #9,r29					; reset CPU int

	load (r31),r28				; get return address
	addq #2,r28					; fix up return

	addq #4,r31					; fix up int stack

	jump (r28)					; go back to work!
	store r29,(r30)				; restore flags

runGPU::
; a little initialization, then enable CPU interrupts
; Init some registers in bank 0 for interrupt usage
	moveq	#0,r0			; just have 0 handy
	movei   #ISTACK,r31     ; Initialize Interrupt Stack
	movei	#gpudraw,r27	; save off this address
	movei	#animbuffer,r26	; save this one too
	movei	#exitint,r25	; and this one
	movei	#keyframe,r23	; etc.
	movei	#decode,r22
	movei	#G_HIDATA,r3	; just to clear it, we don't need it again
	store	r0,(r3)			; speeds the gpu clear, since the blitter may be busy
	
; for the horizon color code	
	movei	#64,r7			; immediate value used in horizon calculation (saves two addq's)
	movei	#.lwait1,r8		; address of main loop
	movei	#$7ff,r18		; mask for VC
	movei	#VC,r20			; Address of VC
	movei	#BG,r21			; get the address of the background register
	movei	#255,r15		; make negative positive
	movei	#1984,r16		; saturated blue in RGB16
	
; Update the GPU flags
	movei	#G_FLAGS,r2	
	moveq	#0,r1
	bset	#4,r1			; enable CPU interrupts
;	bset	#15,r1			; enable DMA priority load/store operations (screws up storep!)
	store	r1,(r2)
	nop

; Main loop - while waiting for interrupt, we calculate the next sky/ground gradient color
; we watch the line buffer, and update the clear color
; to get a nice sky and earth gradient ;)
; This is kind of bad, it shares work registers with the interrupt routine. Race/crash potential??

	loadw (r20),r24		; save old scanline
.lwait1:
	nop
	loadw (r20),r4
	and r18,r4			; mask VC off to just a line counter
	shrq #1,r4			; divide by 2
	cmp r4,r24			; wait for a change
	jr EQ,.lwait1
	nop
	move r4,r24			; save the old value

	; some interleaving here to reduce stalls. Even though the performance
	; of this code is not critical, stalls may impact the ability of the
	; interrupt routine to start quickly?
	
	; preload some temp values for below
	move r15,r2		; make negative positive
	move r16,r3		; saturated blue in RGB16

	; get the current scanline, and the current horizon line register
	movei #170,r17	; hard coded in this one

	; It's time! Based on the current line set a line color
	; the size of each gradient will be 255 pixels
	; Color mode is rrrrrbbbbbgggggg. We already have the line in r4.
	sub r17,r4			; get the offset
			;	(Stall)
	jr MI,.top
	nop		;	(delay slot)

	; Here we are on the bottom. r4 contains a positive value
	; and we need to use it as a green value 
	shlq #1,r4			; multiply by 2
	;	(stall)
	add r7,r4			; add a bit extra (64 for now)
	;	(stall)
	sat8 r4				; saturate to 8 bits

	jr T,.setline		; jump to setting the register
	shrq #2,r4			; (delay slot) reduce to 6 bits 

.top:
	; Here we are on the top, r4 contains a negative value
	; which we need to add to 255 then use as red and green,
	; along with a full blue
	; Despite the repeated instructions on r1 and r4, this 
	; works out to about 12 steps versus 16 including stalls
	; when doing the common work on r4 before the copy
	
.if 0	
	move r16,r4				; force to saturated blue
							; the lion takes too long to decompress due
							; to the byte accesses of external memory,
							; so for now mask it by making the top half
							; of the screen a solid color (Actually, it's better now
							; that I'm not looping over blank data - still need
							; to fix it though)
.else							
	move r4,r1				; make a copy
	add r2,r4				; add 255 for green
				add r2,r1		; add 255 for red
	sat8 r4					; saturate green to 8 bits
				sat8 r1			; saturate red to 8 bits
	shrq #2,r4				; reduce green to 6 bits
				shrq #3,r1		; reduce red to 5 bits
	or r3,r4				; or fixed blue into green
				shlq #11,r1		; shift red to correct location
	; (stall)
	or r1,r4				; or red into green
.endif
		
.setline:
	; update the BG register with the value calculated by the main routine
	jump T,(r8)			; loop
	storew r4,(r21)		; (delay slot) write the value into the BG register 

end_GPU::

; storage for GPU draw address - decodes from this address when interrupted by CPU
; this code is not copied into GPU memory
	.long
gpudraw::		; address must be dword aligned!
	nop
	nop
keyframe::		; 0 for no key, 1 to erase cell before drawing
	nop
	nop
	
.end	

