# FPGA SPI Controller for ADXL362 Accelerometer

This repository contains the RTL design and FPGA hardware implementation of a parameterized SPI Master controller. The system is designed in SystemVerilog to communicate with an ADXL362 3-axis accelerometer, extract real-time acceleration data, and process it on-chip.

## Project Highlights
* **Hardware Validation:** Successfully prototyped and validated on an FPGA board, proving the logical correctness of the SPI protocol and sensor integration prior to ASIC migration.
* **Architecture:** Developed a custom 5-state Finite State Machine (FSM) utilizing shift-register topologies to handle multi-byte read/write operations efficiently.
* **Clock Management:** Implemented on-chip clock dividers to step down the FPGA system clock to the precise frequency required by the ADXL362 SPI interface.

## Repository Structure
* `/rtl` - SystemVerilog source files (`top.v`, `spi_master.v`, etc.)
* `/tb` - Simulation testbench files (`tb_top.v`)
* `/constraints` - Physical FPGA pin mapping files (e.g., `.xdc` / `.qsf`)
* `/docs` - Hardware setup photos, block diagrams, power reports, and simulation waveforms.

## Toolchain & Hardware
* **Target Hardware:** FPGA (e.g., Xilinx / Intel platform)
* **Sensor:** Analog Devices ADXL362 (3-axis MEMS Accelerometer)
* **Design Language:** Verilog
