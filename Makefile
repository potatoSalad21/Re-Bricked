build:
	@rgbasm -o out/breakout.o src/main.asm
	@rgblink -o out/breakout.gb out/breakout.o
	@rgbfix -v -p 0xFF out/breakout.gb
