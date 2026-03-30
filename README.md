A fully-connected layer NPU:
- Written in SystemVerilog and implemented on Arty A7 FPGA.
- Uses 8-input, 4-output inference using 8-bit signed Q4.4 arithmetic.
- Implemented a pipelined memory read -> MAC capture –> accumulation -> ReLU datapath with FSM control.
- Enables 4 parallel MAC lanes and reduces inference latency by ~3× versus a pipelined single-MAC baseline.
- Met timing at 100 MHz on Arty A7 FPGA (+0.101 ns WNS) using 74 LUTs, 120 FFs, and 4 DSPs.
