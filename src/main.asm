INCLUDE "./include/hardware.inc"

DEF BRICK_LEFT   EQU $05
DEF BRICK_RIGHT  EQU $06
DEF BLANK_TILE   EQU $08
DEF DIGIT_OFFSET EQU $1A
DEF SCORE_TENS   EQU $9870
DEF SCORE_ONES   EQU $9871

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0  ; leave space for the header

EntryPoint:

WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank
    ld a, 0
    ld [rLCDC], a

    ld a, 0
    ld b, 40 * 4
    ld hl, _OAMRAM
    call ClearAllObjs

    ; copy tiles
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call Memcpy

    ; copy tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call Memcpy

    ; draw paddle tile
    ld de, Paddle
    ld hl, $8000
    ld bc, PaddleEnd - Paddle
    call Memcpy

    ; draw ball tile
    ld de, Ball
    ld hl, $8010
    ld bc, BallEnd - Ball
    call Memcpy

    ld a, 0
    ld b, 40 * 4
    ld hl, _OAMRAM
    call ClearAllObjs

    ;; init paddle obj
    ld hl, _OAMRAM
    ld a, 128+16    ; Y
    ld [hl+], a
    ld a, 16+8      ; X
    ld [hl+], a
    ld a, 0
    ; obj ID and attributes set to 0
    ld [hl+], a
    ld [hl+], a

    ;; init ball obj
    ld a, 100 + 16    ; Y
    ld [hl+], a
    ld a, 32 + 8    ; X
    ld [hl+], a
    ld a, 1     ; ID
    ld [hl+], a
    ld a, 0     ; Attributes
    ld [hl+], a

    ;; turn LCD on
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
    ; init display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    ;; init global vars
    ld a, 0
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wScore], a
    ld a, 1
    ld [wBalldx], a
    ld a, -1
    ld [wBalldy], a


GameLoop:
    ld a, [rLY]
    cp 144
    jp nc, GameLoop ; wait till screen is not blank
WaitVBlank2:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank2

    ;; move the ball
    ld a, [wBalldx]
    ld b, a
    ld a, [_OAMRAM + 5]
    add a, b
    ld [_OAMRAM + 5], a

    ld a, [wBalldy]
    ld b, a
    ld a, [_OAMRAM + 4]
    add a, b
    ld [_OAMRAM + 4], a

    ;; collision system for walls
BounceTop:
    ; in gb (8, 16) is (0, 0) on screen!
    ld a, [_OAMRAM + 4]     ; Y
    sub a, 16 + 1
    ld c, a
    ld a, [_OAMRAM + 5]     ; X
    sub a, 8
    ld b, a
    call GetTileByPx    ; hl = tile addr
    ld a, [hl]
    call IsWallTile
    jp nz, BounceRight
    call HandleBrickColl
    ld a, 1
    ld [wBalldy], a

BounceRight:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 - 1
    ld b, a
    call GetTileByPx
    ld a, [hl]
    call IsWallTile
    jp nz, BounceLeft
    call HandleBrickColl
    ld a, -1
    ld [wBalldx], a

BounceLeft:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 + 1
    ld b, a
    call GetTileByPx
    ld a, [hl]
    call IsWallTile
    jp nz, BounceBottom
    call HandleBrickColl
    ld a, 1
    ld [wBalldx], a

BounceBottom:
    ld a, [_OAMRAM + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPx
    ld a, [hl]
    call IsWallTile
    jp nz, BounceDone
    call HandleBrickColl
    ; ball hit the floor - die
    call IsBottomTile
    jp z, DeathEvent
    ; ball hit the top of a brick - bounce
    ld a, -1
    ld [wBalldy], a
BounceDone:

    ;; collision for the paddle
    ; cmp Y positions of objs
    ld a, [_OAMRAM]     ; Paddle Y
    ld b, a
    ld a, [_OAMRAM + 4] ; Ball Y
    add a, 5
    cp a, b
    jp nz, PaddleHitDone
    ; cmp X positions of objs
    ld a, [_OAMRAM + 5]     ; Paddle X
    ld b, a
    ld a, [_OAMRAM + 1]     ; Ball X
    sub a, 8
    cp a, b
    jp nc, PaddleHitDone
    add a, 8 + 16
    cp a, b
    jp c, PaddleHitDone

    ld a, -1
    ld [wBalldy], a
PaddleHitDone:

    ;; check pressed buttons
    call TakeInput

CheckLeft:
    ld a, [wCurKeys]
    and a, PADF_LEFT
    jp z, CheckRight
Left:
    ld a, [_OAMRAM + 1]
    dec a
    cp a, 15    ; check bounds
    jp z, GameLoop

    ld [_OAMRAM + 1], a     ; move left
    jp GameLoop

CheckRight:
    ld a, [wCurKeys]
    and a, PADF_RIGHT
    jp z, GameLoop
Right:
    ld a, [_OAMRAM + 1]
    inc a
    cp a, 105   ; check bounds
    jp z, GameLoop

    ld [_OAMRAM + 1], a
    jp GameLoop

TakeInput:
    ld a, P1F_GET_BTN   ; polling
    call .nibble
    ld b, a

    ld a, P1F_GET_DPAD
    call .nibble
    swap a
    xor a, b
    ld b, a

    ld a, P1F_GET_NONE  ; controller released
    ldh [rP1], a

    ld a, [wCurKeys]
    xor a, b    ; a -> keys that changed state
    and a, b    ; a -> keys that changed to pressed
    ld [wNewKeys], a
    ld a, b
    ld [wCurKeys], a
    ret

.nibble:
    ldh [rP1], a
    call .burnret   ; burn 10 cycles (not sure why but needs to be here)
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]    ; key matrix settled
    or a, $F0

.burnret:
    ret


; Function for checking if the ball hit the bottom
; @param a: tile ID
; @return z: set if tile ID matches floor tile's ID
IsBottomTile:
    cp a, $09
    ret z
    ret

; TODO: display screen messages accordingly
DeathEvent:
    jp EntryPoint

WinEvent:
    jp EntryPoint

; Function to clear all objects
; @param a: 0 value
; @param b: OAM size
; param hl: _OAMRAM
ClearAllObjs:
    ld [hl+], a
    dec b
    jp nz, ClearAllObjs
    ret

; Function for copying memory
; @param de: src
; @param hl: dest
; @param bc: length
Memcpy:
    ld a, [de]
    ld [hl+], a
    dec bc
    inc de
    ld a, b
    or a, c
    jp nz, Memcpy
    ret

; Function for converting a pixel to tilemap addr
; hl = $9800 + X + Y*32
; @param b: X
; @param c: Y
; @return hl: Tile Address
GetTileByPx:
    ; mask the Y position
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    ; hl has pos * 8 now
    add hl, hl      ; pos * 16
    add hl, hl      ; pos * 32
    ; convert X to an offset
    ld a, b
    srl a       ; a / 2
    srl a
    srl a       ; a / 8
    ; add two offsets
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ; add the offset to tilemap's base addr
    ld bc, $9800
    add hl, bc
    ret

; @param a: tile ID
; @return z: set if true
IsWallTile:
    ; check all wall tile IDs
    cp a, $00
    ret z
    cp a, $01
    ret z
    cp a, $02
    ret z
    cp a, $04
    ret z
    cp a, $05
    ret z
    cp a, $06
    ret z
    cp a, $07
    ret z
    cp a, $09
    ret z
    ret

; Function to handle brick collision
; bricks are made of two tiles, need to clean up both of them
; @param  hl: tile address
HandleBrickColl:
    ld a, [hl]
    cp a, BRICK_LEFT
    jr nz, HandleBrickRight
    ld [hl], BLANK_TILE     ; if collided with left side
    inc hl
    ld [hl], BLANK_TILE
    call IncScoreBCD
HandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ld [hl], BLANK_TILE     ; if collided with right side
    dec hl
    ld [hl], BLANK_TILE
    call IncScoreBCD
    ret

; Function to increase score
; stores new score as 1 byte packed BCD number
IncScoreBCD:
    xor a   ; clear c flag and a
    inc a
    ld hl, wScore
    adc [hl]
    daa     ; convert to BCD
    ld [hl], a
    call UpdateScoreLabel
    ld a, [wScore]
    cp 33
    jp z, WinEvent
    ret

; Function to read BCD score and update score label
UpdateScoreLabel:
    ld a, [wScore]
    and %11110000           ; mask lower nibble
    swap a                  ; move upper nibble to lower nibble
    add a, DIGIT_OFFSET     ; get digit tile
    ld [SCORE_TENS], a

    ld a, [wScore]
    and %00001111           ; mask upper nibble
    add a, DIGIT_OFFSET
    ld [SCORE_ONES], a
    ret

Tiles:
    ;; premade tiles
    dw `33333333
    dw `33333333
    dw `33333333
    dw `33322222
    dw `33322222
    dw `33322222
    dw `33322211
    dw `33322211

    dw `33333333
    dw `33333333
    dw `33333333
    dw `22222222
    dw `22222222
    dw `22222222
    dw `11111111
    dw `11111111

    dw `33333333
    dw `33333333
    dw `33333333
    dw `22222333
    dw `22222333
    dw `22222333
    dw `11222333
    dw `11222333

    dw `33333333
    dw `33333333
    dw `33333333
    dw `33333333
    dw `33333333
    dw `33333333
    dw `33333333
    dw `33333333

    dw `33322211
    dw `33322211
    dw `33322211
    dw `33322211
    dw `33322211
    dw `33322211
    dw `33322211
    dw `33322211

    dw `22222222
    dw `20000000
    dw `20111111
    dw `20111111
    dw `20111111
    dw `20111111
    dw `22222222
    dw `33333333

    dw `22222223
    dw `00000023
    dw `11111123
    dw `11111123
    dw `11111123
    dw `11111123
    dw `22222223
    dw `33333333

    dw `11222333
    dw `11222333
    dw `11222333
    dw `11222333
    dw `11222333
    dw `11222333
    dw `11222333
    dw `11222333

    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000

    dw `11001100
    dw `11111111
    dw `11111111
    dw `21212121
    dw `22222222
    dw `22322232
    dw `23232323
    dw `33333333

    ; duck logo
    dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222211
	dw `22222211

	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `11221111
	dw `11221111
	dw `11000011

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11222222
	dw `11222222
	dw `11222222

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222211
	dw `22222200
	dw `22222200
	dw `22000000
	dw `22000000
	dw `22222222
	dw `22222222
	dw `22222222

	dw `11000011
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11000022

	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222222
	dw `22222200
	dw `22222200
	dw `22222211
	dw `22222211
	dw `22221111
	dw `22221111
	dw `22221111

	dw `11000022
	dw `00112222
	dw `00112222
	dw `11112200
	dw `11112200
	dw `11220000
	dw `11220000
	dw `11220000

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22000000
	dw `22000000
	dw `00000000
	dw `00000000
	dw `00000000

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11110022
	dw `11110022
	dw `11110022

	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22222211
	dw `22222211
	dw `22222222

	dw `11220000
	dw `11110000
	dw `11110000
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222

	dw `00000000
	dw `00111111
	dw `00111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222

	dw `11110022
	dw `11000022
	dw `11000022
	dw `00002222
	dw `00002222
	dw `00222222
	dw `00222222
	dw `22222222

    ; digits
    ; 0
    dw `33333333
    dw `33000033
    dw `30033003
    dw `30033003
    dw `30033003
    dw `30033003
    dw `33000033
    dw `33333333
    ; 1
    dw `33333333
    dw `33300333
    dw `33000333
    dw `33300333
    dw `33300333
    dw `33300333
    dw `33000033
    dw `33333333
    ; 2
    dw `33333333
    dw `33000033
    dw `30330003
    dw `33330003
    dw `33000333
    dw `30003333
    dw `30000003
    dw `33333333
    ; 3
    dw `33333333
    dw `30000033
    dw `33330003
    dw `33000033
    dw `33330003
    dw `33330003
    dw `30000033
    dw `33333333
    ; 4
    dw `33333333
    dw `33000033
    dw `30030033
    dw `30330033
    dw `30330033
    dw `30000003
    dw `33330033
    dw `33333333
    ; 5
    dw `33333333
    dw `30000033
    dw `30033333
    dw `30000033
    dw `33330003
    dw `30330003
    dw `33000033
    dw `33333333
    ; 6
    dw `33333333
    dw `33000033
    dw `30033333
    dw `30000033
    dw `30033003
    dw `30033003
    dw `33000033
    dw `33333333
    ; 7
    dw `33333333
    dw `30000003
    dw `33333003
    dw `33330033
    dw `33300333
    dw `33000333
    dw `33000333
    dw `33333333
    ; 8
    dw `33333333
    dw `33000033
    dw `30333003
    dw `33000033
    dw `30333003
    dw `30333003
    dw `33000033
    dw `33333333
    ; 9
    dw `33333333
    dw `33000033
    dw `30330003
    dw `30330003
    dw `33000003
    dw `33330003
    dw `33000033
    dw `33333333
TilesEnd:

Tilemap:
    db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $1A, $1A, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
    dw `00033000
    dw `00322300
    dw `03222230
    dw `03222230
    dw `00322300
    dw `00033000
    dw `00000000
    dw `00000000
BallEnd:

;; GLOBALS
SECTION "Counter", WRAM0
wFrameCounter: db   ; reserve 1 byte (in ram)

SECTION "IO Vars", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Ball Vars", WRAM0
wBalldx: db
wBalldy: db

SECTION "Score", WRAM0
wScore: db
