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
reg [`BLKSIZE_W-1:0] blksize;
wire [3:0] wbm_sel_o;

sd_wb_sel_ctrl sd_wb_sel_ctrl_dut(
    .wb_clk(wb_clk),
    .rst(rst),
    .ena(ena), 
    .base_adr_i(base_adr_i),
    .wbm_adr_i(wbm_adr_i),
    .blksize(blksize),
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
    blksize = 0;

    #(3.2*TCLK);
    rst = 0;
    #TCLK;
    
    $display("sd_wb_sel_ctrl_tb start ...");

    assert(wbm_sel_o == 4'hf);

    ena = 1;
    blksize = 1;
    base_adr_i = 1;
    wbm_adr_i = 0;
    $display("przed clk");
    #TCLK;
    $display("po clk");

    assert(wbm_sel_o == 4'h4) else $display("wbm_sel_o == %x", wbm_sel_o);
    wbm_adr_i = 4;
    #(TCLK/2);
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);
    ena = 0;
    #TCLK;

/*
    assert(wbm_sel_o == 4'hf);
    wbm_adr_i = 4;
    #(TCLK/2);
    ena = 0;    
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);
    #TCLK;

    ena = 1;
    blksize = 8;
    base_adr_i = 0;
    wbm_adr_i = 0;
    #TCLK;

    assert(wbm_sel_o == 4'hf);
    wbm_adr_i = 4;
    #(TCLK/2);
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);
    wbm_adr_i = 8;
    #(TCLK/2);
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);
    wbm_adr_i = 12;
    #(TCLK/2);
    ena = 0;
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);

    #TCLK;

    ena = 1;
    blksize = 4;
    base_adr_i = 1;
    wbm_adr_i = 0;
    #TCLK;

    assert(wbm_sel_o == 4'h7);
    wbm_adr_i = 4;
    #(TCLK/2);
    $display("%x", wbm_sel_o);
    assert(wbm_sel_o == 4'h8);
    #(TCLK/2);

    wbm_adr_i = 8;
    #(TCLK/2);
    ena = 0;
    assert(wbm_sel_o == 4'hf);
    #(TCLK/2);

    #TCLK;*/

    #(10*TCLK) $display("sd_wb_sel_ctrl_tb finish ...");
    $finish;
    
end

endmodule 
