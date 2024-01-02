; 
; This file is part of Vidsync for Book8088 (https://github.com/jhhoward/vidsync).
; Copyright (c) 2024 James Howard
; 
; This program is free software: you can redistribute it and/or modify  
; it under the terms of the GNU General Public License as published by  
; the Free Software Foundation, version 3.
;
; This program is distributed in the hope that it will be useful, but 
; WITHOUT ANY WARRANTY; without even the implied warranty of 
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License 
; along with this program. If not, see <http://www.gnu.org/licenses/>.
;
 
;
; Vidsync for Book8088 by James Howard
;
; A DOS TSR that wraps the BIOS video functions to briefly show a pixel in the
; top left and bottom right edges of the framebuffer to allow the Book8088's
; LCD display to calibrate to the screen position correctly.
;

cpu 8086
bits 16
org  0x100      

;
; Program starts here
;
main:
	; get address of the existing 0x10 video interrupt vector
	mov ax, 0x3510
	int 21h
	mov [cs:old_isr], es
	mov [cs:old_isr + 2], bx
	
	; set to video mode 1 (40x25 text) to force a complete screen mode change
	mov ax, 0x1
	int 0x10 		
		
	; replace interrupt vector 0x10 with our wrapper
	mov ax, cs
	mov ds, ax
    mov dx, new_isr    
	mov ax, 0x2510
    int 21h             

	; set video mode to 3 to test the interrupt routine 
	mov ax, 0x3 
	int 0x10 	

print_message:
	mov  dx, msg      
	mov  ah, 9        
	int  0x21         

exit:
	mov  ax, 0x3100     ; terminate and stay resident
	mov  dx, 0x100		; how many paragraphs of memory to reserve
	int  0x21 

;
; Function to restore the old ISR (unused)
;
restore_isr:
	mov ds, [cs:old_isr]
	mov dx, [cs:old_isr + 2]
	mov ax, 0x2510
    int 21h 
	mov ax, cs
	mov ds, ax
	ret
	
;
; Replacement ISR for 0x10 BIOS video routines
;
new_isr:
	mov [cs:old_ax], ax
	cmp ah, 0				; is this a call to set the video mode? (ah = 0)
	jne call_old_isr
	
	; Push a new return address on the stack so that we can run some
	; custom code immediately after the BIOS routine has finished
	pushf
	mov ax, cs
	push ax
	mov ax, post_set_video_mode
	push ax
	
call_old_isr:
	; Do a far jump by pushing the address of the old ISR and a far return
	; so that all registers can be preserved
	mov ax, [cs:old_isr]
	push ax
	mov ax, [cs:old_isr + 2]
	push ax
	mov ax, [cs:old_ax]
	retf
	
;
; Called immediately after the 'set screen mode' video BIOS routine has completed
;
post_set_video_mode:
	push ax
	push si
	push es
	push di
	push dx
	push cx
	
	; If the call to set video mode was successful then the mode number should
	; be stored in the BIOS data area at 40:49
	mov cx, [cs:old_ax]
	mov ax, 0x40
	mov es, ax
	mov di, 0x49
	cmp cl, [es:di]
	jne skip_calibration
	
	; Check if the screen mode was the same as last time and if so, skip calibration
	cmp cl, [cs:last_screen_mode]
	je skip_calibration
	mov [cs:last_screen_mode], cl
	
	; Enable interrupts so that keyboard + timer can be processed during the delay
	sti
	
	; Uses a lookup table to find which area of memory to modify to set
	; a pixel in the top left and bottom right of the frame buffer
	; Calculate table position based on video mode (10 bytes per entry)
	mov si, [cs:old_ax]
	mov ax, 10
	mul si
	mov si, ax
	add si, pixel_write_table
	
	; Apply to top left
	mov es, [cs:si]
	mov di, [cs:si+2]
	mov al, [cs:si+4]
	xor [es:di], al
	
	; Apply to bottom right
	mov es, [cs:si+5]
	mov di, [cs:si+7]
	mov al, [cs:si+9]
	xor [es:di], al
	
	; Wait in a busy loop for the LCD display to calibrate
	mov	dx,20
wait_loop:
	mov	cx,0xffff	
wait_loop2:
	loop wait_loop2;
	dec dx
	jnz wait_loop

	; Remove from top left
	mov es, [cs:si]
	mov di, [cs:si+2]
	mov al, [cs:si+4]
	xor [es:di], al
	
	; Remove from bottom right
	mov es, [cs:si+5]
	mov di, [cs:si+7]
	mov al, [cs:si+9]
	xor [es:di], al
	
skip_calibration:
	
	pop cx
	pop dx
	pop di
	pop es
	pop si
	pop ax
	
	iret
	
;
; Data and variables
;
	
msg  db 'Vidsync for Book8088 v1.0 by James Howard', 0x0d, 0x0a, 'TSR enabled. For details see: https://github.com/jhhoward/vidsync', 0x0d, 0x0a, '$'   ; $-terminated message

old_isr:	
	dw 0		; segment
	dw 0		; offset
	
old_ax 	dw 0

last_screen_mode db 0xff

; Table of video memory addresses for toggling top left and bottom right pixels
; Format is address segment:offset, byte pattern to xor
pixel_write_table:
; 00  40x25 B/W text (CGA,EGA,MCGA,VGA)
	dw	0xb800, 1
	db	0x70
	dw	0xb800, 0x7cf
	db	0x70
; 01  40x25 16 color text (CGA,EGA,MCGA,VGA)
	dw	0xb800, 1
	db	0x70
	dw	0xb800, 0x7cf
	db	0x70
; 02  80x25 16 shades of gray text (CGA,EGA,MCGA,VGA)
	dw	0xb800, 1
	db	0x70
	dw	0xb800, 0xf9f
	db	0x70
; 03  80x25 16 color text (CGA,EGA,MCGA,VGA)
	dw	0xb800, 1
	db	0x70
	dw	0xb800, 0xf9f
	db	0x70
; 04  320x200 4 color graphics (CGA,EGA,MCGA,VGA)
	dw	0xb800, 0
	db	0xc0
	dw	0xba00, 0x1f3f
	db	0x3
; 05  320x200 4 color graphics (CGA,EGA,MCGA,VGA)
	dw	0xb800, 0
	db	0xc0
	dw	0xba00, 0x1f3f
	db	0x3
; 06  640x200 B/W graphics (CGA,EGA,MCGA,VGA)
	dw	0xb800, 0
	db	0x80
	dw	0xba00, 0x1f3f
	db	0x1
; 07  80x25 Monochrome text (MDA,HERC,EGA,VGA)
	dw	0xb000, 1
	db	0x70
	dw	0xb000, 0xf9f
	db	0x70
; 08  160x200 16 color graphics (PCjr)
	dw	0xb800, 0
	db	0x0
	dw	0xb800, 0
	db	0x0
; 09  320x200 16 color graphics (PCjr)
	dw	0xb800, 0
	db	0x0
	dw	0xb800, 0
	db	0x0
; 0A  640x200 4 color graphics (PCjr)
	dw	0xb800, 0
	db	0x0
	dw	0xb800, 0
	db	0x0
; 0B  Reserved (EGA BIOS function 11)
	dw	0xb800, 0
	db	0x0
	dw	0xb800, 0
	db	0x0
; 0C  Reserved (EGA BIOS function 11)
	dw	0xb800, 0
	db	0x0
	dw	0xb800, 0
	db	0x0
; 0D  320x200 16 color graphics (EGA,VGA)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x1f3f
	db	0x01
; 0E  640x200 16 color graphics (EGA,VGA)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x3e7f
	db	0x01
; 0F  640x350 Monochrome graphics (EGA,VGA)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x6d5f
	db	0x01
; 10  640x350 16 color graphics (EGA or VGA with 128K)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x6d5f
	db	0x01
; 11  640x480 B/W graphics (MCGA,VGA)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x95ff
	db	0x01
; 12  640x480 16 color graphics (VGA)
	dw	0xa000, 0
	db	0x80
	dw	0xa000, 0x95ff
	db	0x01
; 13  320x200 256 color graphics (MCGA,VGA)	
	dw	0xa000, 0
	db	0x01
	dw	0xa000, 0xf9ff
	db	0x01
