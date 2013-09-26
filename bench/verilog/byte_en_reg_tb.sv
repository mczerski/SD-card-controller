//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// byte_en_reg_tb.v                                             ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for byte_en_reg module.                            ////
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

module byte_en_reg_tb();

parameter TCLK = 20; // 50 MHz -> timescale 1ns
parameter DATA_W = 31;
parameter EN_W = (DATA_W-1)/8+1;

reg clk;
reg rst;
reg we;
reg [EN_W-1:0] en;
reg [DATA_W-1:0] d;
wire [DATA_W-1:0] q;

byte_en_reg #(.DATA_W(DATA_W)) byte_en_reg_dut(
	.clk(clk),
	.rst(rst),
	.we(we),
	.en(en),
	.d(d),
	.q(q)
	);
	
// Generating clk clock
always
begin
    clk=0;
    forever #(TCLK/2) clk = ~clk;
end

task write_test;
	input [EN_W-1:0] enable;
	input [DATA_W-1:0] data;
	input [DATA_W-1:0] expected_result;
	input integer line;
	begin

		we = 1;
		en = enable;
		d = data;
		#TCLK;
		we = 0;
		en = 0;
		d = 0;
		assert(q == expected_result) else begin $display("in line %d", line); assert(0); end
		
	end
endtask

initial
begin
    rst = 1;
    we = 0;
    en = 0;
    d = 0;
    
    $display("byte_en_reg_tb start ...");
    
    #(3.2*TCLK);
    rst = 0;
    
    assert(q == 0);
    
    //no write
	en = 4'hf;
	d = 31'h12345678;
	#TCLK;
	we = 0;
	en = 0;
	d = 0;
	assert(q == 0);
    
    //simple write (all enable)
    write_test(4'hf, 31'h12345678, 31'h12345678, `__LINE__);
    
    //byte enables (1 byte)
    write_test(4'h1, 31'h7fffffff, 31'h123456ff, `__LINE__);
    write_test(4'h2, 31'h6eeeeeee, 31'h1234eeff, `__LINE__);
    write_test(4'h4, 31'h5ddddddd, 31'h12ddeeff, `__LINE__);
    write_test(4'h8, 31'h4ccccccc, 31'h4cddeeff, `__LINE__);
    
    //byte enables (2 bytes)
    write_test(4'h3, 31'h3bbbbbbb, 31'hccddbbbb, `__LINE__);
    write_test(4'h6, 31'h2aaaaaaa, 31'hccaaaabb, `__LINE__);
    write_test(4'hc, 31'h19999999, 31'h1999aabb, `__LINE__);

    //byte enables (3 bytes)
    write_test(4'h7, 31'h12345678, 31'h19345678, `__LINE__);
    write_test(4'he, 31'hdeadbeef, 31'h5eadbe78, `__LINE__);

    #(10*TCLK) $display("byte_en_reg_tb finish ...");
    $finish;
end

endmodule
