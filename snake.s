	;------------------------------------------------------------------------------------
	; VMU-snake Copyright (c) 2001-2002 Fredrik Ehnbom
	;------------------------------------------------------------------------------------
	;
	; Some source comes from Marcus Comstedt
	; http://mc.pp.se/dc/vms/
	;
	; Features:
	;  - a cool snake game for your VMU :)
	;  - the snake grows longer and longer for each foodpiece it eats
	;  - it also moves faster and faster for each piece
	;
	; Known Bugs:
	;  - the snake can move out of the screen to the left
	;
	; Todo:
	;  - "press a+b to start game"-screen
	;  - game over screen
	;  - highscore list??
	;
	; Here we go!
	;
	;------------------------------------------------------------------------------------


	; include the "Special Function Register"-specification file created by Marcus
	; (described at http://mc.pp.se/dc/vms/sfr.html)
	.include "sfr.i"

snakelength	equ	$30	; current length of the snake
snakeoff	equ	$31	; the position of  the snake in x
snakebyte	equ	$32	; the position of the snake in y
snakedir	equ	$33	; which way the snake is heading
snakenewdir	equ	$34	; the new direction of the snake
scorelo		equ	$35	; the lower byte of the score
scorehi		equ	$36	; the higher byte of the score
pieceoff	equ	$37	; the the dataoffset for the piece
piecebyte	equ	$38	; the pixel in a byte
seed		equ	$39	; random seed
snakeeoff	equ	$3A	; endpoint offset
snakeebyte	equ	$3B	; endpoint byte
speed		equ	$3C	; speed of the game
snakegleft	equ	$3D	; how many segments the snake has left to grow
snakegrow	equ	$3E	; how many segments the snake should grow
snakebody	equ	$3F	; the body of the snake


	; interrupts
	.org	0 		; reset
	jmpf	start

	; INT0 interrupt (external)
	.org	$3
	jmp	nop_irq

	; INT1 interrupt (external)
	.org	$b
	jmp	nop_irq

	; INT2 interrupt (external) or T0L overflow
	.org	$13
	jmp	nop_irq

	; INT3 interrupt (external) or Base Timer overflow
	.org	$1b
	jmp	nop_irq

	; T0H overflow
	.org	$23
	jmp	nop_irq

	; T1H or T1L overflow
	.org	$2b
	jmp	nop_irq

	; SIO0 interrupt
	.org	$33
	jmp	nop_irq

	; SIO1 interrupt
	.org	$3b
	jmp	nop_irq

	; RFB interrupt
	.org	$43
	jmp	nop_irq

	; p3 interrupt
	.org	$4b
	clr1	p3int,0
	clr1	p3int,1
nop_irq:
	reti

	.org	$1f0
goodbye:
	not1	ext,0
	jmpf	goodbye

	; Header
	.org	$200
	; Name
	.byte	"VMU-Snake       "
	; Description
	.byte	"VMU-Snake by Fredrik Ehnbom     "
	; Creator application
	.byte	"aslc86k         "
	; Icon header: number of frames
	.word	1
	; Icon header: speed
	.word	10
	; Icon header: eyecatch
	.word	0
	; Icon header: crc, unused in game
	.word	0
	; Length of file data, unused in game
	.word	0,0
	; Reserved
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	.include "icon.i"

	; Main program starts here
start:
	clr1	ie,7		; disable all irq
	mov	#$a1,ocr	; 32KHz
	mov	#$09,mcr	; LCD scanning, no cursor, gfx mode
	mov	#$80,vccr	; LCD on, enable writing
	clr1	p3int,0		; disable P3 irq
	clr1	p1,7		; ???
	mov	#$ff,p3		; enable pull-ups on P3 (buttons)

	clr1	psw,1		; Get random seed from current minute and
	ld	$1c		; second system variables
	xor	$1d
	set1	psw,1
	st	seed

	set1	ie,7		; enable all irq
startgame:
	call	clrscr		; clear the screen
	call	drawscoreline	; separate the score from the rest of the screen

	mov	#0,acc		; set score to zero
	st	scorehi
	st	scorelo

	mov	#30,speed	; speed of the game

	mov	#snakebody,0	; reset movement history
	mov	#1,acc
.clearloop:
	mov	#0,@R0
	inc	0
	dec	acc
	bnz	.clearloop

	mov	#1, snakelength	; begin with one segment
	mov	#2, snakegleft	; and let it grow to 3
	mov	#1, snakegrow
	mov	#0, snakedir	; move left
	mov	#0, snakenewdir
	mov	#2, snakeoff
	mov	#3, snakeeoff
	mov	#3, snakebyte
	mov	#%11000000, snakeebyte

	ld	snakebyte	; avoid the bugging pixel
	st	c
	ld	snakeoff
	st	b
	call	putpixel

	call	updatesnake
	call	updatepiece	; put the piece at a random location
	ld	speed
	st	2
	mov	#1,3
gameloop:
	call	getkeys		; check button status
	bn	acc,0,.up
	bn	acc,1,.down
	bn	acc,2,.left
	bn	acc,3,.right
	br	.cont
.right:
	ld	snakedir
	be	#0, .cont
	mov	#2, snakenewdir
	br	.cont
.up:
	ld	snakedir
	be	#3, .cont
	mov	#1, snakenewdir
	br	.cont
.down:
	ld	snakedir
	be	#1, .cont
	mov	#3, snakenewdir
	br	.cont
.left:
	ld	snakedir
	be	#2, .cont
	mov	#0, snakenewdir
	br	.cont
.cont:
	dec	2		; decrease counter
	ld	2		; load counter
	bnz	gameloop
	call	updatescore	; draw the score
	ld	speed		; how much to sleep
	st	2
	dec	3
	ld	3
	bnz	gameloop
	mov	#1,3

	ld	snakenewdir	; update snakedirection
	st	snakedir	; if it is not done this way we will be able to kill the snake by for example,
				; if the snake is going to the left, press first up and then right quickly.
				; one might call this an anti-selfcollusion-fix :-)

	call	updatesnake	; repaint snake
	ld	snakelength	; load snakelength (0 if dead)
	bnz	gameloop	; check if still playing
	jmp	startgame	; everything played, so for now just restart
				; (Game Over screen might come later)

	;*****************************************************************************************
	; Function: drawscoreline
	;
	; draws a line which separates the score count from the rest of the gamefield
	;
	;*****************************************************************************************
drawscoreline:
	push	ocr		; store oscillator
	clr1	ocr,5		; we access screen, no more subclock
	push	acc		; store acc
	push	xbnk		; store LCD banking register
	push	2		; used as counter
	mov	#0,xbnk		; LCD bank 0
.dcl:	mov	#$84,2		; init counter
.dcl2:	mov	#%00000011,@R2	; clear byte in LCD ram
	ld	2
	add	#6		; forward one row
	st	2
	mov	#%00000011,@R2	; clear byte in LCD ram
	ld	2
	add	#10		; forward one row
	st	2
	bn	psw,cy,.dcl2	; test for end of LCD bank
	bp	xbnk,0,.end	; skip to end if last LCD bank
	mov	#1,xbnk		; continue in LCD bank 1
	br	.dcl		; start again
.end:	pop	2		; restore R2
	pop	xbnk		; restore LCD bank
	pop	acc		; restore acc
	pop	ocr		; restore oscillator

	ret


	;*****************************************************************************************
	; Function: putpixel
	;
	; this will xor the target pixel
	;
	; Inputs:
	;	b = the dataoffset
	;	c = the pixelbyte
	; Scratch:
	; 	2, acc
	;*****************************************************************************************
putpixel:
	ld	b
	sub	#128
	bp	psw,cy,.bank0	; test if the carry-bit is set
	mov	#1,xbnk		; if it is not, choose xbank 1
	br	.put
.bank0:
	add	#128		; add the 128 we subtracted in the beginning
	mov	#0,xbnk		; choose xbank 0
.put:
	add	#$80
	st	2
	ld	c
	xor	@R2
	st	@R2
	ld	2		; we want a pixel twice as big so repeat
	add	#6		; for the next row
	st	2
	ld	c
	xor	@R2
	st	@R2

	ret

	;*****************************************************************************************
	; Function: updatepiece
	;
	; gets a random value and scales it (division)
	;
	; Inputs:
	;	b = scalevalue
	;
	; Outputs:
	;	acc = scaled random value
	;
	; Scratch:
	;	c
	;*****************************************************************************************
getpieceval:
	call	random		; get a random value between 0 and 255
	st	c		; save it in the c register
	mov	#0, acc		; clear the acc register
	div			; do division (scale)
	ret

	;*****************************************************************************************
	; Function: updatepiece
	;
	; Puts the food at a new random location
	;
	;*****************************************************************************************
updatepiece:
	push	b
	push	acc
	push	c
	push	2

	clr1	ocr,5		; put cpu in 600khz mode
.redo:
	mov	#16, b		; scalevalue for "y"-offset to loose accuracy
	call	getpieceval

	ld	c		; scale it up again
	add	acc		; * 2
	add	acc		; * 4
	add	acc		; * 8
	add	acc		; * 16
	st	c
	st	pieceoff

	mov	#13, b		; get a random value for "x"
	call	getpieceval
	ld	c
	st	2

	mov	#0, acc		; calculate the byteoffset in "x"
	mov	#4, b
	div

	ld	c
	add	pieceoff
	st	pieceoff

	ld	c		; now calculate how the byte should look
	bz	.skip
.loop1:
	ld	2		; "2" has our pixelposition in x
	sub	#4
	st	2
	dec	c
	ld	c
	bnz	.loop1

.skip:
	inc	2
	ld	2

	mov	#%00000011, piecebyte
.loop2:
	ld	piecebyte
	ror
	ror
	st	piecebyte
	dec	2
	ld	2
	bnz	.loop2

	ld	piecebyte	; now get ready to put the pixel on the screen
	st	c
	ld	pieceoff
	st	b
	call	testpixel	; test if the piece is on the snake
	bnz	.redo		; the piece was on the snake... do everything again...

	call	putpixel


	set1	ocr,5		; put cpu back to 32khz mode

	pop	2
	pop	c
	pop	acc
	pop	b
	ret

	;*****************************************************************************************
	; Function: testpixel
	;
	; Tests if there allready is a pixel there 
	;
	; Inputs:
	;	b = the dataoffset
	;	c = the pixel to test with
	; Outputs:
	; 	acc = 0 if no pixel is there
	;*****************************************************************************************
testpixel:
	push	2
	ld	b
	sub	#128
	bp	psw,cy,.bank0
	mov	#1,xbnk
	br	.test
.bank0:
	add	#128
	st	b
	mov	#0,xbnk
.test:
	add	#$80
	st	2
	ld	@R2
	and	c
	pop	2
	ret

	;*****************************************************************************************
	; Function: updatescore
	;
	; Decrease the score by one and draw the score to the screen
	;
	; Inputs:
	;	scorehi, scorelo = the current score
	; Outputs:
	; 	scorehi, scorelo = the new score
	;*****************************************************************************************
updatescore:
	push	acc
	push	2
	push	c
	ld	scorehi		; if the score is 0 then don't decrease it
	bnz	.decrease
	ld	scorelo
	bz	.skip
.decrease:
	ld	scorelo
	sub	#1		; "dec" does not affect any psw-flags 
	st	scorelo		; that is why sub has to be used
	ld	scorehi
	subc	#0
	st	scorehi
.skip:
	ld	scorelo
	st	c
	ld	scorehi
	mov	#1,xbnk
	call	drawdig2
	mov	#0,xbnk
	call	drawdig2
	pop	c
	pop	2
	pop	acc

	ret

	;*****************************************************************************************
	; Function: drawdig2
	;
	; Draws two digits for the score indicator
	;
	; Inputs:
	;	acc,c = a 16-bit number.  The two least significant
	;		digits will be displayed.
	;
	; Outputs:
	;	acc,c = The remaining digits (i.e. input number / 100)
	;
	; Scratch:
	;	2
	;	b
	;*****************************************************************************************
	
drawdig2:
	mov #$c5,2
	mov #10,b
	div
	call drawdigit
	mov #$85,2
	mov #10,b
	div
	; fallthrough to drawdigit...

	;*****************************************************************************************
	; Function: drawdigit
	;
	; Draws one scoredigit
	;
	; Inputs:
	;	2 = where to draw the digit
	;	b = the character to draw
	; Scratch:
	; 	2
	;	b
	;*****************************************************************************************
drawdigit:
	clr1	ocr,5		; put cpu in 600khz mode
	push	trl
	push	trh
	push	acc
	push	c
	mov	#<scorefont,trl
	mov	#>scorefont,trh
	mov	#0,acc		; find characterdata-offset
	mov	#8,c
	mul
	ld	c
	st	b
.loop:			; start drawing to screen
	ld	b
	ldc
	st	@R2
	ld	2
	add	#6		; jump to next row
	st	2
	inc	b
	ld	b
	ldc
	st	@R2
	ld	2
	add	#10		; jump to next row. also every "even" row
	st	2		; features a 4 byte padding. that is why
	inc	b		; I do not branch earlier
	ld	b
	and	#7
	bnz	.loop
	pop	c
	pop	acc
	pop	trh
	pop	trl
	set1	ocr,5		; put cpu back to 32khz mode
	ret

	;*****************************************************************************************
	; Function: getnextpixel
	;
	; updates the byteoffset and bytevalue according to the value in acc
	; 00000000 = left
	; 00000001 = up
	; 00000010 = right
	; 00000011 = down
	;
	; Inputs:
	;	acc = holds information in which direction the snake moves
	;	b = the old byteoffset
	;	c = the old bytevalue
	; Outputs:
	;	b = the new byteoffset
	;	c = the new byte
	; Scratch:
	; 	acc
	;*****************************************************************************************
getnextpixel:
	be	#0, .left
	be	#1, .up
	be	#2, .right
.down:
	ld	b
	add	#16
	st	b
	mov	#0, acc
	addc	#0
	bnz	.die
	br	.end
.left:
	ld	c
	rol
	rol
	st	c
	bne	#%00000011, .end
	dec	b
	br	.end
.up:
	ld	b
	sub	#16
	st	b
	mov	#0, acc
	addc	#0
	bnz	.die
	br	.end
.right:
	ld	c
	ror
	ror
	st	c
	bne	#%11000000, .end
	inc	b
	br	.end
.die:
	mov	#0,acc
	ret
.end:
	mov	#1,acc
	ret

	;*****************************************************************************************
	; Function: updatesnake
	;
	; Moves the snake
	;
	;*****************************************************************************************
updatesnake:
	push	acc
	push	b
	push	c
	push	2
	push	3
	push	0
	push	1

	clr1	ocr,5			; put cpu in 600khz mode

	ld	snakeoff		; update the "head"-pixel
	st	b
	ld	snakebyte
	st	c
	ld	snakedir
	call	getnextpixel
	bnz	.food

	mov	#0,snakelength		; snake is dead...
	jmpf	.end

.food:
	ld	b
	st	snakeoff
	ld	c
	st	snakebyte

	ld	snakeoff		; check if the snake ate the food
	bne	pieceoff, .alivetest
	ld	snakebyte
	bne	piecebyte, .alivetest

	inc	snakegrow		; if so make it grow
	ld	snakegrow
	add	snakegleft
	st	snakegleft

	ld	snakegrow		; and increase the score
	st	c
	mov	#0, acc
	mov	#50, b
	mul

	add	scorehi
	st	scorehi

	ld	scorelo
	add	c
	st	scorelo
	ld	scorehi
	addc	#0
	st	scorehi

	ld	speed
	be	#1,.speedskip
	dec	speed			; and increase the speed (by decreasing the sleep amount)

.speedskip:
	call	updatepiece
	br	.pskip
.alivetest:
	call	testpixel		; check for collusion
	bz	.alive

	mov	#0,snakelength		; the snake is dead
	jmpf	.end

.alive:
	call	putpixel
.pskip:
	ld	snakelength	; update "body"

	st	c		; calculate how many bytes is used for the body
	mov	#0, acc
	mov	#4, b
	div

	mov	#2, b
.loop:
	ld	c
	st	0		; number of bytes
	inc	0

	mov	#snakebody, 1	; address of the snakebody

	ld	b
	be	#1, .skip1

	ld	snakedir
	rorc
	br	.loop2

.skip1:
	ld	snakedir
	ror
	rorc

.loop2:
	ld	@R1
	rorc
	st	@R1

	ld	0
	bz	.skip

	inc	1		; move on to next byte
	dec	0		; decrease byte counter
	ld	0		; test for zero
	bnz	.loop2
.skip:
	dec	b		; decrease pass counter
	ld	b		; and check if we have done the two passes
	bnz	.loop

	ld	snakegleft	; check if the snake is growing
	bnz	.grow


	mov	#snakebody, acc	; get byteoffset
	add	c		; "c" has how many bytes the snake uses (-1)
	st	0

	ld	@R0
	st	0

	mov	#0, acc		; calculate how many segments we should skip
	mov	#4, b
	mul

	ld	snakelength
	sub	c


	st	1		; how many times we should "ror"
	mov	#3, acc
	sub	1
	st	3

	bz	.putend
.loop3:
	ld	0
	ror
	ror
	st	0
	dec	3
	ld	3
	bnz	.loop3

.putend:
	ld	0
	and	#%00000011
	st	0

	ld	snakeeoff
	st	b
	ld	snakeebyte
	st	c
	ld	0
	call	getnextpixel
	ld	b
	st	snakeeoff
	ld	c
	st	snakeebyte
	call	putpixel

	br	.end
.grow:
	inc	snakelength
	dec	snakegleft
.end:
	set1	ocr,5

	pop	1
	pop	0
	pop	3
	pop	2
	pop	c
	pop	b
	pop	acc

	ret


	;*****************************************************************************************
	;*****************************************************************************************
	;*****************************************************************************************


	; everything down below are routines from marcus
	; I might have made some smaller modifications though

clrscr:	
	push ocr		; store oscillator
	clr1 ocr,5		; we access screen, no more subclock
	push acc		; store acc
	push xbnk		; store LCD banking register
	push 2			; used as counter
	mov #0,xbnk		; LCD bank 0
.cbank:	mov #$80,2		; init counter
.cloop:	mov #0,@R2		; clear byte in LCD ram
	inc 2			; advance counter
	ld 2			; get counter
	and #$f			; test for end of even row
	bne #$c,.cskip		; no, continue
	ld 2			; end of even row, get counter
	add #4			; start of next row
	st 2			; put counter
.cskip:	ld 2			; get counter
	bnz .cloop		; test for end of LCD bank
	bp xbnk,0,.cexit	; skip to end if last LCD bank
	mov #1,xbnk		; continue in LCD bank 1
	br .cbank		; start again
.cexit:	pop 2			; restore R2
	pop xbnk		; restore LCD bank
	pop acc			; restore acc
	pop ocr			; restore oscillator
	ret

getkeys:
	bp	p7,0,quit
	ld	p3
 	bn	acc,6,quit
	bn	acc,7,sleep
	ret

quit:
	jmp goodbye

sleep:
	bn p3,7,sleep		; Wait for SLEEP to be depressed
	mov #0,vccr		; Blank LCD
;	call	suspendtune	; stop sound playing
sleepmore:
	set1 pcon,0		; Enter HALT mode
	bp p7,0,quit		; Docked?
	bp p3,7,sleepmore	; No SLEEP press yet
	mov #$80,vccr		; Reenable LCD
;	call restarttune	; continue sound playing
waitsleepup:
	bn p3,7,waitsleepup
	br getkeys

	;; Function:	random
	;;
	;; Generates a pseudo-random value in the range 0-255
	;;
	;; Inputs:
	;;   seed = previous random seed
	;;
	;; Outputs:
	;;   seed = new random seed
	;;   acc  = generated random value
random:
	push b
	push c
	ld seed
	st b
	mov #$4e,acc
	mov #$6d,c
	mul
	st b
	ld c
	add #$39
	st seed
	ld b
	addc #$30
	pop c
	pop b
	ret

	; score-font (by marcus.. might have modified it a bit.. can't remember)
scorefont:
	.byte %10000011
	.byte %00111001
	.byte %00110001
	.byte %00101001
	.byte %00101001
	.byte %00011001
	.byte %10000011
	.byte %11111111

	.byte %11001111
	.byte %10001111
	.byte %11001111
	.byte %11001111
	.byte %11001111
	.byte %11001111
	.byte %10000111
	.byte %11111111

	.byte %10000011
	.byte %00111001
	.byte %11111001
	.byte %10000011
	.byte %00111111
	.byte %00111111
	.byte %00000001
	.byte %11111111

	.byte %10000011
	.byte %00111001
	.byte %11111001
	.byte %11100011
	.byte %11111001
	.byte %00111001
	.byte %10000011
	.byte %11111111

	.byte %00111001
	.byte %00111001
	.byte %00111001
	.byte %00000001
	.byte %11111001
	.byte %11111001
	.byte %11111001
	.byte %11111111

	.byte %00000001
	.byte %00111111
	.byte %00111111
	.byte %00000011
	.byte %11111001
	.byte %00111001
	.byte %10000011
	.byte %11111111

	.byte %10000011
	.byte %00111001
	.byte %00111111
	.byte %00000011
	.byte %00111001
	.byte %00111001
	.byte %10000011
	.byte %11111111

	.byte %00000001
	.byte %11111001
	.byte %11111001
	.byte %11110011
	.byte %11100111
	.byte %11100111
	.byte %11100111
	.byte %11111111

	.byte %10000011
	.byte %00111001
	.byte %00111001
	.byte %10000011
	.byte %00111001
	.byte %00111001
	.byte %10000011
	.byte %11111111

	.byte %10000011
	.byte %00111001
	.byte %00111001
	.byte %10000001
	.byte %11111001
	.byte %00111001
	.byte %10000011
	.byte %11111111

