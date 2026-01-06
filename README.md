# HPIB Parallel Port Adapter

A DOS TSR driver and utilities that allow HPIB (HP-IB/GPIB/IEEE-488) printers to be used as standard parallel printers through a simple passive cable.

**Author:** John L. Sokol
**Date:** December 1990 - January 1991
**License:** Public Domain

## Background

In the early 1990s, we acquired a pallet of surplus HP inkjet printers with HPIB (IEEE-488) interfaces. Rather than purchasing expensive GPIB controller cards ($500+), this software bit-bangs the IEEE-488 protocol directly through the PC parallel port using a passive cable adapter.

The result: any DOS application that can print to LPT1 works transparently with HPIB printers.

## How It Works

The TSR (`HPRN.COM`) hooks INT 17h (BIOS printer services) and translates standard parallel printer commands into IEEE-488 three-wire handshake protocol:

1. **DAV** (Data Valid) - Directly-driven talker handshake
2. **NRFD** (Not Ready For Data) - Listener ready signal
3. **NDAC** (Not Data Accepted) - Listener accepted signal
4. **ATN** (Attention) - Command/data mode select
5. **SRQ** (Service Request) - Device requesting service

## Cable Wiring Diagram

### Parallel Port (DB-25 Female) to HPIB (IEEE-488 24-pin)

```
    PC PARALLEL PORT                         HPIB/GPIB/IEEE-488
    (DB-25 Female)                           (24-pin Centronics)
    ===============                          ===================

    DATA LINES (directly active-low accent inverted in software):
    Pin 2  (D0) ─────────────────────────── Pin 1  (DIO1)
    Pin 3  (D1) ─────────────────────────── Pin 2  (DIO2)
    Pin 4  (D2) ─────────────────────────── Pin 3  (DIO3)
    Pin 5  (D3) ─────────────────────────── Pin 4  (DIO4)
    Pin 6  (D4) ─────────────────────────── Pin 13 (DIO5)
    Pin 7  (D5) ─────────────────────────── Pin 14 (DIO6)
    Pin 8  (D6) ─────────────────────────── Pin 15 (DIO7)
    Pin 9  (D7) ─────────────────────────── Pin 16 (DIO8)

    HANDSHAKE LINES:
    Pin 1  (Strobe)    ──────────────────── Pin 6  (DAV)
    Pin 14 (Auto LF)   ──────────────────── Pin 7  (NRFD)
    Pin 16 (Init)      ──────────────────── Pin 11 (ATN)
    Pin 17 (Select In) ──────────────────── Pin 8  (NDAC)

    STATUS LINES:
    Pin 15 (Error)     ──────────────────── Pin 10 (SRQ)

    AUTO-DETECT JUMPER (optional - enables auto port detection):
    Pin 11 (Busy)      ──────────────────── Pin 16 (Init) [directly looped on parallel side]

    GROUND:
    Pin 18-25 (Ground) ──────────────────── Pin 12,17-24 (Ground/Shield)
```

### Signal Logic Notes

- **Data lines are inverted** in software (`XOR $FF`) to match HPIB active-low convention
- **ATN (Init pin)** is hardware-inverted on the parallel port control register
- The auto-detect jumper shorts pins 11↔16 on the parallel port side only

### ASCII Diagram

```
     DB-25 (Parallel)              IEEE-488 (HPIB)
    ┌─────────────────┐           ┌─────────────────┐
    │  1 ─────────────│───────────│─── 6  DAV       │
    │  2 ─────────────│───────────│─── 1  DIO1      │
    │  3 ─────────────│───────────│─── 2  DIO2      │
    │  4 ─────────────│───────────│─── 3  DIO3      │
    │  5 ─────────────│───────────│─── 4  DIO4      │
    │  6 ─────────────│───────────│─── 13 DIO5      │
    │  7 ─────────────│───────────│─── 14 DIO6      │
    │  8 ─────────────│───────────│─── 15 DIO7      │
    │  9 ─────────────│───────────│─── 16 DIO8      │
    │ 14 ─────────────│───────────│─── 7  NRFD      │
    │ 15 ─────────────│───────────│─── 10 SRQ       │
    │ 16 ─────┬───────│───────────│─── 11 ATN       │
    │ 11 ─────┘       │           │                 │
    │ 17 ─────────────│───────────│─── 8  NDAC      │
    │ 18-25 ──────────│───────────│─── 12,17-24 GND │
    └─────────────────┘           └─────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `src/HPRN3.ASM` | **Main TSR driver** - Hooks INT 17h, provides transparent HPIB printing |
| `src/GPIB1.PAS` | Interactive keyboard-to-HPIB test program |
| `src/GPIB2.PAS` | File-to-HPIB printer utility |
| `src/HPR2.PAS` | Full GPIB controller with serial polling support |
| `src/ADDR1.PAS` | GPIB address utilities |
| `src/ADDR2.PAS` | GPIB address utilities |
| `src/HPRINT.PAS` | File printer utility |
| `src/HPRN1.ASM` | Earlier version of printer driver |
| `src/HPRN2.ASM` | Earlier version of printer driver |
| `src/AB.ASM` | Unrelated: Audio Byte sound player (SPLAY) |

## Building

### TSR Driver (HPRN.COM)

Using MASM or TASM:
```
MASM HPRN3.ASM;
LINK HPRN3.OBJ;
EXE2BIN HPRN3.EXE HPRN.COM
```

Or with TASM:
```
TASM HPRN3.ASM
TLINK /t HPRN3.OBJ,HPRN.COM
```

### Pascal Utilities

Using Turbo Pascal 5.0+:
```
TPC GPIB2.PAS
```

## Usage

### Installing the TSR

```
HPRN
```

Output:
```
PORT Address Autodetected
HPIB emulation on LPT 1
```

The driver will:
1. Auto-detect which LPT port has the HPIB cable (via pin 11↔16 jumper)
2. Hook INT 17h for that port
3. Stay resident (~160 bytes)

### Printing

Once installed, any DOS print command works:
```
COPY DOCUMENT.TXT LPT1:
PRINT REPORT.TXT
```

Or from any application (WordPerfect, Lotus 1-2-3, etc.) - just print to LPT1.

### Direct Printing (without TSR)

```
GPIB2 FILENAME.TXT
```

## Technical Details

### Port Mapping

| Parallel Port | Address | GPIB Signal Mapping |
|---------------|---------|---------------------|
| Data Register | $378 | DIO1-DIO8 (inverted) |
| Status Register | $379 | Bit 3 = SRQ |
| Control Register | $37A | Bit 0 = DAV, Bit 1 = NRFD, Bit 2 = ATN, Bit 3 = NDAC |

### Three-Wire Handshake Protocol

```
Talker (PC)                          Listener (Printer)
-----------                          ------------------
1. Place data on bus (inverted)
2. Wait for NRFD=0 (ready)
3. Assert DAV=0 (data valid)
4. Wait for NDAC=0 (accepted)
5. Release DAV=1
6. Repeat...
```

### Installation Detection

The TSR uses a signature check to prevent double-loading:
- Call INT 17h with DX=0xFFFF
- If already installed, returns DX=0xBACE

## Limitations

- Talker-only implementation (PC sends to printer)
- No bidirectional communication support
- Status reporting is minimal (returns fixed 0x90)
- Single device only (no GPIB addressing for multiple devices)

## History

This code was written in 1990-1991 to repurpose surplus HPIB inkjet printers for standard DOS use. Rather than letting perfectly good hardware go to waste, a simple cable and ~160 bytes of resident code turned them into usable office printers.

## See Also

- [IEEE-488 Wikipedia](https://en.wikipedia.org/wiki/IEEE-488)
- [HP-IB History](https://en.wikipedia.org/wiki/HP-IB)
