salvador -- a fast, near-optimal compressor for the ZX0 format
==============================================================

salvador is a command-line tool and a library that compresses bitstreams in the ZX0 format. 

The tool outputs compressed files that are within 0.02% on average, of the files produced by the zx0 packer itself. The compressor is, however, several orders of magnitude faster, with compression speed similar to [apultra](https://github.com/emmanuel-marty/apultra). 

The compressor can pack files of any size, however, due to the 31.5 KB window size, files larger than 128-256 KB will get a better ratio with apultra. This will not be an issue when compressing for the main target, 8-bit micros. By default, salvador compresses for the modern (V2) format. The classic, legacy format is also supported; use the -classic flag on the command line.

salvador is written in portable C. It is fully open-source under a liberal license. You can use the ZX0 decompression libraries for your target environment. As with LZSA and apultra, you can do whatever you like with it.

The output is fully compatible with the [ZX0](https://github.com/einar-saukas/ZX0) compressor by Einar Saukas.

Check out [Dali](https://csdb.dk/release/?id=213694&show=summary) by Bitbreaker, that uses Salvador to compress for the C64, including self, in-place decompression and proper handling of load-addresses. The tool is part of the [Bitfire](https://github.com/bboxy/bitfire) C64 loading system.

Included 8-bit decompression code:

 * [8088](https://github.com/emmanuel-marty/salvador/tree/main/asm/8088) by Emmanuel Marty. 
 * [68000](https://github.com/emmanuel-marty/salvador/tree/main/asm/68000) by Emmanuel Marty. 
 * [z80](https://github.com/emmanuel-marty/salvador/tree/main/asm/Z80) by spke and uniabis. Use the -classic flag to compress data for the Z80.
 * [6502](https://github.com/emmanuel-marty/salvador/tree/main/asm/6502) by John Brandwood. Use the -classic flag to compress data for the 6502.
 * [HuC6280](https://github.com/emmanuel-marty/salvador/tree/main/asm/HuC6280) by John Brandwood. Use the -classic flag for this platform as well.

External decompression code:

 * [6803](https://github.com/dougmasten/zx0-6803) by Simon Jonassen and Doug Masten. Use the -classic flag to compress data for the 6803.
 * [6809 and 6309](https://github.com/dougmasten/zx0-6x09) by Doug Masten. Use the -classic flag to compress data for the 6809 or 6309 depackers.

License:

* The salvador code is available under the Zlib license.
* The match finder (matchfinder.c) is available under the CC0 license due to using portions of code from Eric Bigger's Wimlib in the suffix array-based matchfinder.
