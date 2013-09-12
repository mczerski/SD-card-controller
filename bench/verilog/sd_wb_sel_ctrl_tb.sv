//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_wb_sel_ctrl_tb.sv                                         ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for sd_wb_sel_ctrl module                          ////
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

module sd_wb_sel_ctrl_tb();

parameter TCLK = 20; // 50 MHz -> timescale 1ns

reg wb_clk;
reg rst;
reg ena;
reg [31:0] base_adr_i;
reg [31:0] wbm_adr_i;
reg [`BLKSIZE_W+`BLKCNT_W-1:0] xfersize;
wire [3:0] wbm_sel_o;

task check_wb_sel;
	input [3:0] expected;
    input integer line;
	begin
        #TCLK;
        assert(wbm_sel_o == expected) else begin $display("in line %d, wbm_sel_o %x", line, wbm_sel_o); assert(0); end
        #TCLK;
        assert(wbm_sel_o == expected) else begin $display("in line %d, wbm_sel_o %x", line, wbm_sel_o); assert(0); end
        #TCLK;
        assert(wbm_sel_o == expected) else begin $display("in line %d, wbm_sel_o %x", line, wbm_sel_o); assert(0); end
    end
endtask

task set_test;
    input [31:0] base_addr;
    input [`BLKSIZE_W+`BLKCNT_W-1:0] xfer_size;
    begin
        ena = 0;
        base_adr_i = base_addr;
        xfersize = xfer_size;
        #TCLK;
        
        ena = 1;
        base_adr_i = 0;
        xfersize = 0;
        #TCLK;
    end
endtask

task end_test;
    begin
        ena = 0;
        #TCLK;
    end
endtask

sd_wb_sel_ctrl sd_wb_sel_ctrl_dut(
    .wb_clk(wb_clk),
    .rst(rst),
    .ena(ena), 
    .base_adr_i(base_adr_i),
    .wbm_adr_i(wbm_adr_i),
    .xfersize(xfersize),
    .wbm_sel_o(wbm_sel_o)
);

// Generating clk clock
always
begin
    wb_clk=0;
    forever #(TCLK/2) wb_clk = ~wb_clk;
end

initial
begin
    rst = 1;
    ena = 0;
    base_adr_i = 0;
    wbm_adr_i = 0;
    xfersize = 0;

    #(3.2*TCLK);
    rst = 0;
    #TCLK;
    
    $display("sd_wb_sel_ctrl_tb start ...");

    check_wb_sel(4'hf, `__LINE__);

    //one byte aligned
    wbm_adr_i = 4;
    set_test(4, 1);
    check_wb_sel(4'h8, `__LINE__);
    wbm_adr_i = 8;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //one byte unaligned
    wbm_adr_i = 0;
    set_test(1, 1);
    check_wb_sel(4'h4, `__LINE__);
    wbm_adr_i = 4;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //two bytes aligned
    wbm_adr_i = 8;
    set_test(8, 2);
    check_wb_sel(4'hc, `__LINE__);
    wbm_adr_i = 12;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //two bytes unaligned
    wbm_adr_i = 8;
    set_test(11, 2);
    check_wb_sel(4'h1, `__LINE__);
    wbm_adr_i = 12;
    check_wb_sel(4'h8, `__LINE__);
    wbm_adr_i = 16;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //three bytes aligned
    wbm_adr_i = 20;
    set_test(20, 3);
    check_wb_sel(4'he, `__LINE__);
    wbm_adr_i = 24;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //three bytes unaligned
    wbm_adr_i = 24;
    set_test(25, 3);
    check_wb_sel(4'h7, `__LINE__);
    wbm_adr_i = 28;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //four bytes aligned
    wbm_adr_i = 32;
    set_test(32, 4);
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 36;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //four bytes unaligned
    wbm_adr_i = 40;
    set_test(42, 4);
    check_wb_sel(4'h3, `__LINE__);
    wbm_adr_i = 44;
    check_wb_sel(4'hc, `__LINE__);
    wbm_adr_i = 48;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //five bytes aligned
    wbm_adr_i = 52;
    set_test(52, 5);
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 56;
    check_wb_sel(4'h8, `__LINE__);
    wbm_adr_i = 60;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //five bytes unaligned
    wbm_adr_i = 64;
    set_test(65, 5);
    check_wb_sel(4'h7, `__LINE__);
    wbm_adr_i = 68;
    check_wb_sel(4'hc, `__LINE__);
    wbm_adr_i = 72;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //eight bytes aligned
    wbm_adr_i = 76;
    set_test(76, 8);
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 80;
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 84;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //eight bytes unaligned
    wbm_adr_i = 84;
    set_test(85, 8);
    check_wb_sel(4'h7, `__LINE__);
    wbm_adr_i = 88;
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 92;
    check_wb_sel(4'h8, `__LINE__);
    wbm_adr_i = 96;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
    
    //19 bytes aligned
    wbm_adr_i = 100;
    set_test(100, 19);
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 104;
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 116;
    check_wb_sel(4'he, `__LINE__);
    wbm_adr_i = 120;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);

    //19 bytes unaligned
    wbm_adr_i = 100;
    set_test(101, 19);
    check_wb_sel(4'h7, `__LINE__);
    wbm_adr_i = 104;
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 116;
    check_wb_sel(4'hf, `__LINE__);
    wbm_adr_i = 120;
    check_wb_sel(4'hf, `__LINE__);
    end_test;
    check_wb_sel(4'hf, `__LINE__);
        
    #(10*TCLK) $display("sd_wb_sel_ctrl_tb finish ...");
    $finish;
    
end

endmodule 
