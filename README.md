# SDRAM Initialization

Verilog FSM that runs the power-up initialization of the ISSI IS42S16320F SDRAM on a DE10-Lite
board at 50 MHz, with a self-checking testbench. Developed with AI assistance.

## Sequence
1. Wait 200 us with NOP commands (datasheet minimum: 100 us)
2. PRECHARGE ALL
3. 8 x AUTO REFRESH (datasheet minimum: 2)
4. LOAD MODE REGISTER: 0x020 (CL=2, sequential, burst length 1)
5. Assert `done`

## Timing at 50 MHz (20 ns clock)
| Parameter | Datasheet worst case (-5/-6/-7) | This design |
|---|---|---|
| tCK at CL=2 | 10 ns minimum | 20 ns |
| tRP | 18 ns | 40 ns |
| tRC | 60 ns | 80 ns |
| tMRD | 2 clocks | 2 clocks |

Source: ISSI IS42/45R86400F/16320F, IS42/45S86400F/16320F datasheet, pp. 18-22 and 25 (Rev. B1).

## Simulate
In ModelSim, from `sim/`, run `do run.do`. The transcript must end with `RESULT: PASS`.

## Bug-injection checks
Each command must report `RESULT: FAIL`:

    vsim -c -gDUT_T_RC_NS=20 -do "run -all; quit" work.tb_sdram_init
    vsim -c -gDUT_REFRESH_COUNT=1 -do "run -all; quit" work.tb_sdram_init

## Results (ModelSim - Intel FPGA Edition 2020.1)
| Run | Result |
|---|---|
| Default design | `RESULT: PASS (2 tests)` |
| `DUT_T_RC_NS=20` | `RESULT: FAIL (24 errors)`: tRC violations |
| `DUT_REFRESH_COUNT=1` | `RESULT: FAIL (3 errors)`: too few REFRESH commands |

The design also compiled in Quartus Prime Lite 20.1.1 with 0 errors. Board testing is pending.

## Limitations
- Initialization only: no ACTIVE, reads, writes, data transfers or periodic refresh yet.
- The testbench checks the commands the FSM issues. It does not include an SDRAM memory model.
- On the board, LEDR[0] only shows that the FSM finished. It does not prove the memory initialized correctly.
