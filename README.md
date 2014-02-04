
Wishbone SD Card Controller IP Core
===================================

The Wishbone SD Card Controller IP Core is MMC/SD communication controller designed to be
used in a System-on-Chip. IP core provides simple interface for any CPU with Wishbone
bus. The communication between the MMC/SD card controller and MMC/SD card is performed
according to the MMC/SD protocol.

Introduction
------------
This core is based on the "sd card controller" project from 
http://opencores.org/project,sdcard_mass_storage_controller 
but has been largely rewritten. A lot of effort has been made 
to make the core more generic and easily usable 
with OSs like Linux. 
- data transfer commands are not fixed 
- data transfer block size is configurable 
- multiple block transfer support 
- R2 responses (136 bit) support

Features
--------

The MMC/SD card controller provides following features:

- 1- or 4-bit MMC/SD mode (does not support SPI mode),
- 32-bit Wishbone interface,
- DMA engine for data transfers,
- Interrupt generation on completion of data and command transactions,
- Configurable data transfer block size,
- Support for any command code (including multiple data block tranfser),
- Support for R1, R1b, R2(136-bit), R3, R6 and R7 responses.

Documentation
-------------

The documentation is located in the doc/ directory.

Examples
--------

A sample ORPSoC project that make use of this core is located at:

https://github.com/mczerski/orpsoc-de0_nano

The project is based on de0_nano board with custom made expansion board
with SD Card connector.

There is also u-boot project port for this board located at:

https://github.com/mczerski/u-boot

This u-boot project contains driver for Wishbone SD Card Controller IP Core
and can be configured for de0_nano board (with custom made expansion board).

Also in the plan is the driver for Linux. The initial work can be found at:

https://github.com/mczerski/linux - de0_nano branch

the driver is named ocsdc and is located in drivers/mmc/host directory.

TODO:
-----

- rx/tx fifo treshold to do block transfers rather than many signle word transfers
- maybe one fifo rathen than two fifos (rx and tx) would suffice since the transfer 
	between card and controller is always half-duplex
- read only and card detect signals support

