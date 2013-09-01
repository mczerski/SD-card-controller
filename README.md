=pod

=head1 Wishbone SD Card Controller IP Core

The Wishbone SD Card Controller IP Core is MMC/SD communication controller designed to be
used in a System-on-Chip. IP core provides simple interface for any CPU with Wishbone
bus. The communication between the MMC/SD card controller and MMC/SD card is performed
according to the MMC/SD protocol.

=head2 Features

The MMC/SD card controller provides following features:

- 1- or 4-bit MMC/SD mode (does not support SPI mode),
- 32-bit Wishbone interface,
- DMA engine for data transfers,
- Interrupt generation on completion of data and command transactions,
- Configurable data transfer block size,
- Support for any command code (including multiple data block tranfser),
- Support for R1, R1b, R2(136-bit), R3, R6 and R7 responses.

=head2 Documentation

The documentation is located in the doc/ directory.

=cut