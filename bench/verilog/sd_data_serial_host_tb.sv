//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_data_serial_host_tb.sv                                    ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for sd_data_serial_host module                     ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "sd_defines.h"

module sd_data_serial_host_tb();

parameter SD_TCLK = 20; // 50 MHz -> timescale 1ns
parameter DATA_IDLE = 4'hf;
parameter DATA_START = 4'h0;
parameter DATA_END = 4'hf;

reg sd_clk;
reg rst;
//Tx Fifo
reg [31:0] data_in;
wire rd;
//Rx Fifo
wire[31:0] data_out;
wire we;
//tristate data
wire DAT_oe_o;
wire [3:0] DAT_dat_o;
reg [3:0] DAT_dat_i;
//Controll signals
reg [`BLKSIZE_W-1:0] blksize;
reg bus_4bit;
reg [`BLKCNT_W-1:0] blkcnt;
reg [1:0] start;
reg [1:0] byte_alignment;
wire sd_data_busy;
wire busy;
wire crc_ok;

integer fifo_send_data[0:3] = {32'h12345678, 32'haabbccdd, 32'h9abcdef0, 32'h55aacc33};
//integer fifo_send_data[0:0] = {32'hffffffff};
reg [1:0] fifo_idx = 0;
integer fifo_receive_data[0:3] = {32'h00010203, 32'ha0a1a2a3, 32'hdeadbeef, 32'hbad00dad};

function [3:0] get_1or4_bits;
    input [3:0] data;
    input integer bits;
    begin
        if (bits == 1)
            get_1or4_bits = {3'b111, data[0]};
        else
            get_1or4_bits = data;
    end
endfunction

function integer crc16;
    input integer crc_in;
    input bit inb;
    begin
        inb = inb ^ crc_in[0];
        crc16 = crc_in >> 1;
        crc16 = crc16 ^ (16'h8408 & {16{inb}});
    end
endfunction

task sd_card_send;
    input integer bytes;
    input integer blocks;
    input integer width;
    input bit crc_failure;
    integer cycles;
    integer i, j;
    integer data_idx;
    integer shift;
    integer crc[0:3];
    reg [3:0] crc_out;
    begin
        assert(width == 1 || width == 4) else $stop;
        while (blocks) begin
            cycles = bytes*8/width;
            crc = '{0, 0, 0, 0};
            //start bits
            DAT_dat_i = get_1or4_bits(DATA_START, width);
            #SD_TCLK;
            //data bits
            for (i=0; i<cycles; i++) begin
                data_idx = (i*width/32)%$size(fifo_receive_data);
                shift = (32-width)-((i*width)%32);
                DAT_dat_i = get_1or4_bits(fifo_receive_data[data_idx] >> shift, width);
                for (j=0; j<4; j++)
                    crc[j] = crc16(crc[j], DAT_dat_i[j]);
                #SD_TCLK;
            end
            //crc bits
            for (i=0; i<16; i++) begin
                for (j=0; j<4; j++)
                    crc_out[j] = crc[j] >> i;
                DAT_dat_i = get_1or4_bits(crc_failure ? 0 : crc_out, width);
                #SD_TCLK;
            end
            //stop bits
            DAT_dat_i = get_1or4_bits(DATA_END, width);
            #SD_TCLK;
            DAT_dat_i = get_1or4_bits(DATA_IDLE, width);
            #SD_TCLK;
            if (blocks-1)
                assert(busy == 1);
            assert(crc_ok == !crc_failure);
            blocks--;
        end
    end
endtask

function integer align_words_to_sd;
    input integer first_word;
    input integer second_word;
    input integer alignment;
    integer i, bitval, tmp;
    begin
        tmp = 0;
        for (i=31; i>=0; i--) begin
            bitval = i >= 8*alignment ? first_word >> (i - 8*alignment) : second_word >> (i+(32-8*alignment));
            bitval = bitval & 1;
            tmp += (bitval << i);
        end
        align_words_to_sd = tmp;
    end
endfunction

task sd_card_receive;
    input integer bytes;
    input integer blocks;
    input integer alignment;
    input integer width;
    input [2:0] crc_status;
    integer cycles;
    integer i, j;
    integer received_data;
    integer data_idx;
    integer shift;
    integer crc[0:3];
    integer crc_in[0:3];
    integer aligned_data;
    integer check_mask;
    //reg [3:0] crc_out;
    begin
        assert(width == 1 || width == 4) else $stop;
        assert(alignment < 4) else $stop;
        cycles = bytes*8/width;
        data_idx = 0;
        while(blocks) begin
            received_data = 0;
            crc = '{0, 0, 0, 0};
            crc_in = '{0, 0, 0, 0};
            //wait for start bits
            wait (DAT_dat_o == get_1or4_bits(DATA_START, width));
            assert(DAT_oe_o == 1);
            #(SD_TCLK/2);
            //data bits
            for (i=0; i<cycles; i++) begin
                #SD_TCLK;
                shift = (32-width)-((i*width)%32);
                for (j=0; j<width; j++)
                    received_data[shift+j] = DAT_dat_o[j];
                assert(DAT_oe_o == 1);
                if ((i*width)%32 == (32-width) || i == cycles-1) begin
                    aligned_data = align_words_to_sd(fifo_send_data[data_idx%$size(fifo_send_data)], fifo_send_data[(data_idx+1)%$size(fifo_send_data)], alignment);
                    if (alignment + (i*width/8)%4 >= 3)
                        data_idx++;
                    //check_mask = 32'hffffffff;
                    case ((i*width/8)%4)
                        0: check_mask = 32'hff000000;
                        1: check_mask = 32'hffff0000;
                        2: check_mask = 32'hffffff00;
                        3: check_mask = 32'hffffffff;
                    endcase
                    aligned_data &= check_mask;
                    received_data &= check_mask;
//                    $display("aligned %x, r %x", aligned_data, received_data);
                    assert(aligned_data == received_data);
                end
                for (j=0; j<width; j++)
                    crc[j] = crc16(crc[j], DAT_dat_o[j]);
            end
            //crc bits
            for (i=0; i<16; i++) begin
                #SD_TCLK;
                assert(DAT_oe_o == 1);
                for (j=0; j<width; j++)
                    crc_in[j][i] = DAT_dat_o[j];
            end
            for (i=0; i<width; i++)
                assert(crc_in[i] == crc[i]);
            //stop bits
            #SD_TCLK;
            assert(DAT_oe_o == 1);
            assert(DAT_dat_o == DATA_END);
            #SD_TCLK;
            assert(DAT_oe_o == 0);
            #(2*SD_TCLK);
            //crc status
            //start bit
            DAT_dat_i = get_1or4_bits(DATA_START, 1);
            #SD_TCLK;
            //crc status bits
            for (i=0; i<$size(crc_status); i++) begin
                DAT_dat_i = {3'h7, crc_status[i]};
                #SD_TCLK;
            end
            //stop bit
            DAT_dat_i = get_1or4_bits(DATA_END, 1);
            #SD_TCLK;
            assert(sd_data_busy == 0);
            //busy bit
            DAT_dat_i = {3'h7, 1'b0};
            #(2*SD_TCLK);
            assert(sd_data_busy == 1);
            if (blocks-1)
                assert(busy == 1);
            if (crc_status == 3'b010)
                assert(crc_ok == 1);
            else
                assert(crc_ok == 0);
            #(10*SD_TCLK);
            DAT_dat_i = DATA_IDLE;
            blocks--;
            alignment = (alignment + bytes) % 4;
        end
        #SD_TCLK;
    end
endtask

function integer align_words_to_wb;
    input integer first_word;
    input integer second_word;
    input integer alignment;
    integer i, bitval, tmp;
    begin
        tmp = 0;
        for (i=31; i>=0; i--) begin
            bitval = i >= 32-8*alignment ? first_word >> (i - (32-8*alignment)) : second_word >> (i+8*alignment);
            bitval = bitval & 1;
            tmp += (bitval << i);
        end
        align_words_to_wb = tmp;
    end
endfunction

task check_single_write;
    input integer bytes;
    input integer rx_alignment;
    input integer verif_alignment;
    input integer index;
    integer aligned_mask, bytes_mask, mask;
    integer aligned_data;
    begin
        case (bytes) 
            1: bytes_mask = 32'hff000000;
            2: bytes_mask = 32'hffff0000;
            3: bytes_mask = 32'hffffff00;
            4: bytes_mask = 32'hffffffff;
        endcase
        case (rx_alignment)
            0: aligned_mask = 32'hffffffff;
            1: aligned_mask = 32'h00ffffff;
            2: aligned_mask = 32'h0000ffff;
            3: aligned_mask = 32'h000000ff;
        endcase
        mask = aligned_mask & bytes_mask;
        aligned_data = align_words_to_wb(fifo_receive_data[(index+$size(fifo_send_data)-1)%$size(fifo_send_data)], fifo_receive_data[index], verif_alignment);
        //$display("masks %x, r %x, a %x", mask, data_out, aligned_data);
        assert((data_out & mask) == (aligned_data & mask));
    end
endtask

task check_fifo_write;
    input integer bytes;
    input integer blocks;
    input integer alignment;
    input integer width;
    integer cycles, i, j;
    begin
        assert(width == 1 || width == 4) else $stop;
        assert(alignment < 4) else $stop;
        while (blocks) begin
            bytes += alignment;
            cycles = bytes/4;
            wait (we == 1);
            #(SD_TCLK/2);
            //if cycles == 0 it means less than 4 bytes to send
            if (cycles)
                check_single_write(4, alignment, alignment, 0);
            else
                check_single_write(bytes, alignment, alignment, 0);
                
            for (i=1; i<cycles; i++) begin
                for (j=0; j<32/width-1; j++) begin
                    #SD_TCLK;
                    assert(we == 0);
                end
                #SD_TCLK;
                assert(we == 1);
                check_single_write(4, 0, alignment, i%$size(fifo_receive_data));
            end
            blocks--;
            if (blocks > 0) begin
                bytes -= alignment;
                alignment = (alignment + bytes) % 4; 
                #SD_TCLK;
            end
        end
        //handle the case when bytes is not a multiple of 4 and more than 4
        if (cycles && (bytes % 4)) begin
            for (j=0; j<((bytes % 4)*8)/width-1; j++) begin
                #SD_TCLK;
                assert(we == 0);
            end
            #SD_TCLK;
            assert(we == 1);
            check_single_write((bytes % 4), 0, alignment, cycles%$size(fifo_receive_data));
        end
    end
endtask

task check_fifo_read;
    input integer bytes;
    input integer blocks;
    input integer alignment;
    input integer width;
    integer cycles, i, j;
    integer read_idx;
    begin
        assert(width == 1 || width == 4) else $stop;
        bytes += alignment;
        cycles = bytes/4;
        read_idx = 1;
//        $display("read_idx %d", read_idx);
//        $display("data_in0 %x", data_in);
//        $display("bytes %d", bytes);
        while (blocks) begin
            if (bytes >= 4) begin
                wait (rd == 1);
                #(SD_TCLK/2);
                assert(rd == 1);
                //read delay !!!
                #(2*SD_TCLK);
                data_in = fifo_send_data[read_idx%$size(fifo_send_data)];
                read_idx++;
//                $display("read_idx %d", read_idx);
//                $display("data_in1 %x", data_in);
                for (i=1; i<cycles; i++) begin
                    for (j=0; j<32/width-1; j++) begin
                        #SD_TCLK;
                        if (j == 32/width-3)
                            assert(rd == 1);
                        else
                            assert(rd == 0);
                    end
                    #SD_TCLK;
                    assert(rd == 0);
                    data_in = fifo_send_data[read_idx%$size(fifo_send_data)];
                    read_idx++;
//                    $display("read_idx %d", read_idx);
//                    $display("data_in2 %x", data_in);
                end
            end
            for (i=0; i<((bytes % 4)*8/width); i++) begin
                assert(rd == 0);
                #SD_TCLK;
            end
//            $display("bytes %d, alignment %d", bytes, alignment);
//            if (width == 4 && (bytes % 4) == 3) begin
//                assert(rd == 1);
//                //read delay !!!
//                #(2*SD_TCLK);
//                data_in = fifo_send_data[read_idx%$size(fifo_send_data)];
//                read_idx++;
//                $display("data_in3 %x", data_in);
//            end
//            else
            assert(rd == 0);
            //$display("data_in %x", data_in);
            blocks--;
            bytes -= alignment;
            alignment = (alignment + bytes) % 4;
            bytes += alignment;
            cycles = bytes/4;
        end
        for (i=0; i<32/width; i++) begin
            #SD_TCLK;
            assert(rd == 0);
        end
    end
endtask

task start_read;
    input integer bsize;
    input integer bcnt;
    input integer alignment;
    input integer b_4bit;
    begin 
    
        assert(bsize > 0 && bcnt > 0);
        rst = 1;
        #(2*SD_TCLK);
        rst = 0;
        blksize = bsize-1;
        blkcnt = bcnt-1;
        byte_alignment = alignment;
        bus_4bit = b_4bit;
        start = 2; //read
        #SD_TCLK;
        blksize = 0;
        byte_alignment = 0;
        bus_4bit = 0;
        blkcnt = 0;
        start = 0;
        assert(busy == 1);
        
    end
endtask

task read_test;
    input integer bsize;
    input integer bcnt;
    input integer alignment;
    input integer b_4bit;
    input bit crc_failure;
    begin
    
        start_read(bsize, bcnt, alignment, b_4bit);
        
        #(20*SD_TCLK);
        
        fork
            sd_card_send(bsize, crc_failure ? 1 : bcnt, b_4bit ? 4 : 1, crc_failure);
            check_fifo_write(bsize, crc_failure ? 1 : bcnt, alignment, b_4bit ? 4 : 1);
        join
        
        #SD_TCLK;
        assert(busy == 0);
        
    end
endtask

task start_write;
    input integer bsize;
    input integer bcnt;
    input integer alignment;
    input integer b_4bit;   
    begin
    
        assert(bsize > 0 && bcnt > 0);
        rst = 1;
        #(2*SD_TCLK);
        rst = 0;
        blksize = bsize-1;
        blkcnt = bcnt-1;
        byte_alignment = alignment;
        bus_4bit = b_4bit;
        start = 1; //write
        #SD_TCLK;
        blksize = 0;
        byte_alignment = 0;
        bus_4bit = 0;
        blkcnt = 0;
        start = 0;
        assert(busy == 1);
        
    end
endtask

task write_test;
    input integer bsize;
    input integer bcnt;
    input integer alignment;
    input integer b_4bit;
    input bit crc_failure;
    begin
    
        start_write(bsize, bcnt, alignment, b_4bit);
        fork
            check_fifo_read(bsize, crc_failure ? 1 : bcnt, alignment, b_4bit ? 4 : 1);
            sd_card_receive(bsize, crc_failure ? 1 : bcnt, alignment, b_4bit ? 4 : 1, crc_failure ? 3'b101 : 3'b010);
        join
        data_in = fifo_send_data[0];
        
        #(2*SD_TCLK);
        assert(busy == 0);
        
    end
endtask

task abort;
    begin
        start = 3;
        #SD_TCLK;
        start = 0;
        assert(busy == 0);
    end
endtask

sd_data_serial_host sd_data_serial_host_dut(
                        .sd_clk         (sd_clk),
                        .rst            (rst),
                        .data_in        (data_in),
                        .rd             (rd),
                        .data_out       (data_out),
                        .we             (we),
                        .DAT_oe_o       (DAT_oe_o),
                        .DAT_dat_o      (DAT_dat_o),
                        .DAT_dat_i      (DAT_dat_i),
                        .blksize        (blksize),
                        .bus_4bit       (bus_4bit),
                        .blkcnt         (blkcnt),
                        .start          (start),
                        .byte_alignment (byte_alignment),
                        .sd_data_busy   (sd_data_busy),
                        .busy           (busy),
                        .crc_ok         (crc_ok)
                    );

// Generating WB_CLK_I clock
always
begin
    sd_clk=0;
    forever #(SD_TCLK/2) sd_clk = ~sd_clk;
end

initial
begin
    rst = 1;
    DAT_dat_i = DATA_IDLE;
    data_in = fifo_send_data[0];
    blksize = 0;
    byte_alignment = 0;
    bus_4bit = 0;
    blkcnt = 0;
    start = 0;
    
    $display("sd_data_serial_host_tb start ...");
    
    #(3*SD_TCLK);
    rst = 0;

    assert(rd == 0);
    assert(we == 0);
    assert(DAT_oe_o == 0);
    assert(busy == 0);
    
    #(3*SD_TCLK);
    
    //tests with 1-bit mode and 4-bit mode
    //single block read and single block write
    //multiple block read and multiple block write
    //test with bad crc (wrong crc during read, wrong rcr in response)
    
    ///////////////////////////////////////////////////////////////
    //1-bit single block read
    read_test(64, 1, 0, 0, 0);

    ///////////////////////////////////////////////////////////////
    //1-bit single block write
    write_test(128, 1, 0, 0, 0);
   
    ///////////////////////////////////////////////////////////////
    //1-bit multiple block read
    read_test(32, 4, 0, 0, 0);
    
    ///////////////////////////////////////////////////////////////
    //1-bit multiple block write
    write_test(16, 9, 0, 0, 0);
    
    ///////////////////////////////////////////////////////////////
    //              4 - bit
    ///////////////////////////////////////////////////////////////
    //4-bit single block read
    read_test(256, 1, 0, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //4-bit single block write
    write_test(512, 1, 0, 1, 0);   
    
    ///////////////////////////////////////////////////////////////
    //4-bit multiple block read
    read_test(8, 18, 0, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //4-bit multiple block write
    write_test(4, 33, 0, 1, 0);

    ///////////////////////////////////////////////////////////////
    //1-bit unaligned block read
    read_test(8, 1, 2, 0, 0);

    ///////////////////////////////////////////////////////////////
    //1-bit unaligned block write
    write_test(16, 1, 1, 0, 0);

    ///////////////////////////////////////////////////////////////
    //1-bit unaligned multiple block read
    read_test(8, 4, 1, 0, 0);

    ///////////////////////////////////////////////////////////////
    //1-bit unaligned multiple block write
    write_test(32, 8, 3, 0, 0);

    ///////////////////////////////////////////////////////////////
    //4-bit unaligned block read
    read_test(64, 1, 2, 1, 0);

    ///////////////////////////////////////////////////////////////
    //4-bit unaligned block write
    write_test(32, 1, 3, 1, 0);
 
    ///////////////////////////////////////////////////////////////
    //4-bit unaligned multiple block read
    read_test(8, 3, 1, 1, 0);

    ///////////////////////////////////////////////////////////////
    //4-bit unaligned multiple block write
    write_test(4, 2, 3, 1, 0);
    
    //////////////////////////////////////////////////////////////
    //      wierd configurations
    //1-bit
    read_test(1, 1, 0, 0, 0);
    write_test(1, 1, 0, 0, 0);
    read_test(2, 1, 0, 0, 0);
    write_test(2, 1, 0, 0, 0);
    read_test(3, 1, 0, 0, 0);
    write_test(3, 1, 0, 0, 0);
    read_test(4, 1, 0, 0, 0);
    write_test(4, 1, 0, 0, 0);
    read_test(5, 1, 0, 0, 0);
    write_test(5, 1, 0, 0, 0);
    read_test(13, 1, 0, 0, 0);
    write_test(19, 1, 0, 0, 0);
    //unaligned single block
    read_test(13, 1, 1, 0, 0);
    write_test(2, 1, 3, 0, 0);
    //unaligned multiple block
    read_test(13, 3, 1, 0, 0);
    write_test(2, 4, 3, 0, 0);

    //4-bit
    read_test(1, 1, 0, 1, 0);
    write_test(1, 1, 0, 1, 0);
    read_test(2, 1, 0, 1, 0);
    write_test(2, 1, 0, 1, 0);
    read_test(3, 1, 0, 1, 0);
    write_test(3, 1, 0, 1, 0);
    read_test(4, 1, 0, 1, 0);
    write_test(4, 1, 0, 1, 0);
    read_test(5, 1, 0, 1, 0);
    write_test(5, 1, 0, 1, 0);
    read_test(13, 1, 0, 1, 0);
    write_test(19, 1, 0, 1, 0);
    //unaligned single block
    read_test(7, 1, 2, 1, 0);
    write_test(9, 1, 1, 1, 0);
    //unaligned multiple block
    read_test(7, 3, 2, 1, 0);
    write_test(1, 14, 1, 1, 0);

    //////////////////////////////////////////////////////////////
    //      bad crc
    //
    read_test(32, 1, 0, 1, 1);
    read_test(16, 4, 0, 1, 1);
    write_test(18, 1, 0, 1, 1);
    write_test(64, 3, 0, 1, 1);
    read_test(32, 1, 0, 1, 0);
    read_test(16, 4, 0, 1, 0);
    write_test(18, 1, 0, 1, 0);
    write_test(64, 3, 0, 1, 0);
    
    //////////////////////////////////////////////////////////////
    //      xfer stopped in the middle
    
    //write stopped when sending data
    start_write(32, 1, 0, 1);
    wait(DAT_dat_o == 0);
    #(SD_TCLK/2);
    #((2*16)*SD_TCLK); //half of data transfer
    
    abort;
    
    //write stopped when waiting for crc status
    start_write(32, 1, 0, 1);
    wait(DAT_dat_o == 0);
    wait(DAT_oe_o == 0);
    #(SD_TCLK/2);
    #(3*SD_TCLK);
    
    abort;

    //write stopped when receiving crc status
    start_write(32, 1, 0, 1);
    wait(DAT_dat_o == 0);
    wait(DAT_oe_o == 0);
    #(SD_TCLK/2);
    
    //card sends crc status
    DAT_dat_i[0] = 0;
    #(2*SD_TCLK);
    DAT_dat_i[0] = 1;
    abort;
    
    //write stopped when card busy
    start_write(32, 1, 0, 1);
    wait(DAT_dat_o == 0);
    wait(DAT_oe_o == 0);
    #(SD_TCLK/2);
    
    //card sends crc status (0010)
    DAT_dat_i[0] = 0;
    #(2*SD_TCLK);
    DAT_dat_i[0] = 1;
    #SD_TCLK;
    DAT_dat_i[0] = 0;
    #(4*SD_TCLK);
    assert(busy == 1);
    abort;

    //read stopped when waiting for data
    start_read(32, 1, 0, 1);
    #(10*SD_TCLK);
    
    abort;
    
    //read stopped when receiving data
    start_read(32, 1, 0, 1);
    #(10*SD_TCLK);
    DAT_dat_i[0] = 0;
    #(10*SD_TCLK);
    
    abort;

    #(100*SD_TCLK) $display("sd_data_serial_host_tb finish ...");
    $finish;
    
end

endmodule
