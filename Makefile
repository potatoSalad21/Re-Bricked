build:
	@rgbasm -o out/rebricked.o src/main.asm
	@rgblink -o out/rebricked.gb out/rebricked.o
	@rgbfix -v -p 0xFF out/rebricked.gb
