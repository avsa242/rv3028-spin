# rv3028-spin
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the RV3028 RTC

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Set date/time
* Set automatic power supply switchover function
* Set CLKOUT clock frequency output
* Set countdown timer, timer source clock freq
* Clock data valid flag

## Requirements

P1/SPIN1:
* 1 extra core/cog for the PASM I2C engine (none if bytecode engine is used)
* time.rtc.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* time.rtc.common.spin2h (provided by p2-spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | NuCode      | OK                    |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | Native code | FTBFS                 |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* TBD

