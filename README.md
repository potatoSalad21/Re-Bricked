# Re;Bricked

## Description
'Re;Bricked' is a fun breakout game written entirely in GameBoy assembly for the sake of teaching myself low level programming. For example, how the data moves from CPU registers and RAM, how CPU translates instructions into action, and how the hardware is controlled.

**Note**: game lacks the win/loss system for now.

## Showcase
https://github.com/user-attachments/assets/aff6d6da-83fc-4b5b-8e36-4b29b7e79058


### Requirements
- POSIX environment
- GNU make
- [RGBDS >v0.5.0](https://rgbds.gbdev.io/install)
- Emulator (such as [Emulicious](https://emulicious.net/))

### How to Build and Run
1. **Clone the repo**
```sh
git clone https://github.com/potatoSalad21/Re-Bricked
cd Re-Bricked
```
2. **Build the game**
```sh
make build
```
3. **Run the gb file in your emulator**

and done!

#### Useful Resources
- [GB ASM by example](https://github.com/daid/gameboy-assembly-by-example)
- [RGBDS Docs](https://rgbds.gbdev.io/docs/v0.9.3)
- [Pan Docs (gameboy tech reference)](https://gbdev.io/pandocs/)
