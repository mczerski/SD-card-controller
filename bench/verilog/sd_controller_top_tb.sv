//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_controller_top_tb.sv                                      ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for sd_controller_top module                       ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// Based on original work by                                    ////
////     Adam Edvardsson (adam.edvardsson@orsoc.se)               ////
////                                                              ////
////     Copyright (C) 2009 Authors                               ////
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

`include "wb_model_defines.h"
`include "sd_defines.h"

`define BIN_DIR "../bin"
`define LOG_DIR "../log"

`define SD_BASE 32'hd0000000
`define CMD2 16'h200
`define CMD3 16'h300
`define ACMD6 16'h600
`define CMD7 16'h700
`define CMD8 16'h800
`define CMD55 16'h3700
`define ACMD41 16'h2900
`define CMD8 16'h800
`define CMD12 16'h0C00
`define CMD16 16'h1000
`define CMD17 16'h1100
`define CMD18 16'h1200
`define CMD24 16'h1800

`define RSP_48 16'h1
`define RSP_136 16'h2
`define CICE 16'h10
`define CRCE 16'h08
`define CRD 16'h20
`define CWD 16'h40

module sd_controller_top_tb
#(parameter ramdisk={`BIN_DIR, "/ramdisk2.hex"},
  parameter sd_model_log_file={`LOG_DIR, "/sd_model.log"},
  parameter wb_m_mon_log_file={`LOG_DIR, "/sdc_tb_wb_m_mon.log"},
  parameter wb_s_mon_log_file={`LOG_DIR, "/sdc_tb_wb_s_mon.log"},
  parameter wb_memory_file={`BIN_DIR, "/wb_memory.txt"})
(

);

parameter TCLK = 20; // 50 MHz -> timescale 1ns

reg wb_clk;
reg wb_rst;
wire [31:0] wbs_sds_dat_i;
wire [31:0] wbs_sds_dat_o;
wire [31:0] wbs_sds_adr_i;
wire [3:0] wbs_sds_sel_i;
wire wbs_sds_we_i;
wire wbs_sds_cyc_i;
wire wbs_sds_stb_i;
wire wbs_sds_ack_o;
wire [31:0] wbm_sdm_adr_o;
wire [3:0] wbm_sdm_sel_o;
wire wbm_sdm_we_o;
wire [31:0] wbm_sdm_dat_i;
wire [31:0] wbm_sdm_dat_o;
wire wbm_sdm_cyc_o;
wire wbm_sdm_stb_o;
wire wbm_sdm_ack_i;
wire [2:0] wbm_sdm_cti_o;
wire [1:0] wbm_sdm_bte_o;

integer failed_tests; //number of failed tests
integer passed_tests; //number of passed tests
reg wbm_working; // tasks wbm_write and wbm_read set signal when working and reset it when stop working

wire sd_cmd_oe;
wire sd_dat_oe;
wire cmdIn;
wire [3:0] datIn;
tri sd_cmd;
tri [3:0] sd_dat;

assign sd_cmd = sd_cmd_oe ? cmdIn: 1'bz;
assign sd_dat =  sd_dat_oe  ? datIn : 4'bz;

sdModel #(.ramdisk (ramdisk),
	  .log_file (sd_model_log_file)) sdModelTB0(
    .sdClk(sd_clk_pad_o),
    .cmd(sd_cmd),
    .dat(sd_dat)
    ); 

sdc_controller sd_controller_top_dut(
    .wb_clk_i(wb_clk),
    .wb_rst_i(wb_rst),
    .wb_dat_i(wbs_sds_dat_i),
    .wb_dat_o(wbs_sds_dat_o),
    .wb_adr_i(wbs_sds_adr_i[7:0]),
    .wb_sel_i(wbs_sds_sel_i),
    .wb_we_i(wbs_sds_we_i),
    .wb_stb_i(wbs_sds_stb_i),
    .wb_cyc_i(wbs_sds_cyc_i),
    .wb_ack_o(wbs_sds_ack_o),
    .m_wb_adr_o(wbm_sdm_adr_o),
    .m_wb_sel_o(wbm_sdm_sel_o),
    .m_wb_we_o(wbm_sdm_we_o),
    .m_wb_dat_o(wbm_sdm_dat_o),
    .m_wb_dat_i(wbm_sdm_dat_i),
    .m_wb_cyc_o(wbm_sdm_cyc_o),
    .m_wb_stb_o(wbm_sdm_stb_o),
    .m_wb_ack_i(wbm_sdm_ack_i),
    .m_wb_cti_o(wbm_sdm_cti_o),
    .m_wb_bte_o(wbm_sdm_bte_o),
    .sd_cmd_dat_i(sd_cmd),
    .sd_cmd_out_o(cmdIn),
    .sd_cmd_oe_o(sd_cmd_oe),
    .sd_dat_dat_i(sd_dat),
    .sd_dat_out_o(datIn),
    .sd_dat_oe_o( sd_dat_oe),
    .sd_clk_o_pad(sd_clk_pad_o),
    .sd_clk_i_pad(wb_clk),
    .int_cmd (int_cmd),
    .int_data (int_data)
    );

WB_MASTER_BEHAVIORAL wb_master0(
    .CLK_I(wb_clk),
    .RST_I(wb_rst),
    .TAG_I(5'h0), //Not in use
    .TAG_O(), //Not in use
    .ACK_I(wbs_sds_ack_o),
    .ADR_O(wbs_sds_adr_i),
    .CYC_O(wbs_sds_cyc_i),
    .DAT_I(wbs_sds_dat_o),
    .DAT_O(wbs_sds_dat_i),
    .ERR_I(1'b0), //Not in use
    .RTY_I(1'b0), //inactive (1'b0)
    .SEL_O(wbs_sds_sel_i),
    .STB_O(wbs_sds_stb_i),
    .WE_O (wbs_sds_we_i),
    .CAB_O() //Not in use
    );

WB_SLAVE_BEHAVIORAL
  #(.wb_memory_file (wb_memory_file))
   wb_slave0(
    .CLK_I(wb_clk),
    .RST_I(wb_rst),
    .ACK_O(wbm_sdm_ack_i),
    .ADR_I(wbm_sdm_adr_o),
    .CYC_I(wbm_sdm_cyc_o),
    .DAT_O(wbm_sdm_dat_i),
    .DAT_I(wbm_sdm_dat_o),
    .ERR_O(),
    .RTY_O(), //Not in use
    .SEL_I(wbm_sdm_sel_o),
    .STB_I(wbm_sdm_stb_o),
    .WE_I (wbm_sdm_we_o),
    .CAB_I(1'b0)
    );
    
integer wb_s_mon_log_file_desc ;
integer wb_m_mon_log_file_desc ;

WB_BUS_MON sdc_eth_slave_bus_mon0(
  .CLK_I(wb_clk),
  .RST_I(wb_rst),
  .ACK_I(wbs_sds_ack_o),
  .ADDR_O({24'h0,wbs_sds_adr_i[7:0]}),
  .CYC_O(wbs_sds_cyc_i),
  .DAT_I(wbs_sds_dat_o),
  .DAT_O(wbs_sds_dat_i),
  .ERR_I(1'b0),
  .RTY_I(1'b0),
  .SEL_O(wbs_sds_sel_i),
  .STB_O(wbs_sds_stb_i),
  .WE_O (wbs_sds_we_i),
  .TAG_I(5'h0),
  .TAG_O(5'h0),
  .CAB_O(1'b0),
  .check_CTI(1'b0),
  .log_file_desc(wb_s_mon_log_file_desc)
);

WB_BUS_MON sdc_eth_master_bus_mon0(
    .CLK_I(wb_clk),
    .RST_I(wb_rst),
    .ACK_I(wbm_sdm_ack_i),
    .ADDR_O(wbm_sdm_adr_o),
    .CYC_O(wbm_sdm_cyc_o),
    .DAT_I(wbm_sdm_dat_i),
    .DAT_O(wbm_sdm_dat_o),
    .ERR_I(1'b0),
    .RTY_I(1'b0),
    .SEL_O(wbm_sdm_sel_o),
    .STB_O(wbm_sdm_stb_o),
    .WE_O (wbm_sdm_we_o),
    .TAG_I(5'h0),
    .TAG_O(5'h0),
    .CAB_O(1'b0),
    .check_CTI(1'b0), //NO need
    .log_file_desc(wb_m_mon_log_file_desc)
    );

task open_log_files;
    begin
        wb_s_mon_log_file_desc = $fopen(wb_s_mon_log_file);
        assert(wb_s_mon_log_file_desc >= 2);
        $fdisplay(wb_s_mon_log_file_desc, "============== WISHBONE Slave Bus Monitor error log ==============");
        $fdisplay(wb_s_mon_log_file_desc, " ");
        $fdisplay(wb_s_mon_log_file_desc, "   Only ERRONEOUS conditions are logged !");
        $fdisplay(wb_s_mon_log_file_desc, " ");

        wb_m_mon_log_file_desc = $fopen(wb_m_mon_log_file);
        assert(wb_m_mon_log_file_desc >= 2);
        $fdisplay(wb_m_mon_log_file_desc, "============= WISHBONE Master Bus Monitor  error log =============");
        $fdisplay(wb_m_mon_log_file_desc, " ");
        $fdisplay(wb_m_mon_log_file_desc, "   Only ERRONEOUS conditions are logged !");
        $fdisplay(wb_m_mon_log_file_desc, " ");
    end
endtask
    
initial
    begin
        // init global values
        failed_tests = 0;
        passed_tests = 0;
        wbm_working = 0;
        wb_slave0.cycle_response(
            `ACK_RESPONSE, 
            1/*wait cycles befor WB Slave responds*/, 
            2/*if RTY response, then this is the number of retries before ACK*/
            );
            
        open_log_files;
        
        $display("sd_controller_top_tb start ...");
    
        test_send_cmd; 
    
        test_init_sequnce;

        test_send_data;

        test_send_rec_data;

        test_send_cmd_error_rsp;

        test_send_rec_data_error_rsp;

        #(10*TCLK) $display("sd_controller_top_tb finish ...");
        $display("All Test finnished. Nr Failed: %d, Nr Passed: %d", failed_tests, passed_tests);

        $finish;
    end

//generate wb_clk clock
always
    begin
        wb_clk=0;
        forever #(TCLK/2) wb_clk = ~wb_clk;    
    end

function [31:0] reg_addr;
    input [7:0] offset;
    begin
        reg_addr = `SD_BASE + offset;
    end
endfunction

task setup_core;
    input integer cmd_timeout;
    input integer data_timeout;
    begin
        hard_reset;
        
        //reset Core
        wbm_write(reg_addr(`reset), 1, 4'hF, 1, 0, $random%5);
        //setup timeout
        wbm_write(reg_addr(`cmd_timeout), cmd_timeout, 4'hF, 1, 0, $random%5);
        //setup data timeout
        wbm_write(reg_addr(`data_timeout), data_timeout, 4'hF, 1, 0, $random%5);
        //setup clock devider
        wbm_write(reg_addr(`clock_d), 16'h0, 4'hF, 1, 0, $random%5);
        //start Core
        wbm_write(reg_addr(`reset), 0, 4'hF, 1, 0, $random%5);
        //enable all cmd_irq
        wbm_write(reg_addr(`cmd_iser), 5'h1f, 4'hF, 1, 0, $random%5);
        //enable all data_irq
        wbm_write(reg_addr(`data_iser), 3'h7, 4'hF, 1, 0, $random%5);
        //set 4-bit bus
        wbm_write(reg_addr(`controller), 1, 4'hF, 1, 0, $random%5);
    end
endtask

task send_cmd;
    input integer command;
    input integer argument;
    output integer status;
    begin
        //Setup cmd xfer
        wbm_write(reg_addr(`command), command, 4'hF, 1, 0, $random%5);
        wbm_write(reg_addr(`argument), argument, 4'hF, 1, 0, $random%5);
        
        //wait for xfer to finnish
        wbm_read(reg_addr(`cmd_isr), status, 4'hF, 1, 0, $random%5);
        while (status[`INT_CMD_CC] != 1 && status[`INT_CMD_EI] != 1)
            wbm_read(reg_addr(`cmd_isr), status, 4'hF, 1, 0, $random%5);

        //clear cmd isr
        wbm_write(reg_addr(`cmd_isr), 0, 4'hF, 1, 0, $random%5);
    end
endtask

`define ASSERT_CMD_STATUS(x) assert(x[1] == 0) x = 1; \
                         else begin \
                             assert(0); \
                             x = 0; \
                             return; \
                         end
                         
`define ASSERT_DATA_STATUS(x) assert(x == 1) \
                         else begin \
                             assert(0); \
                             x = 0; \
                             return; \
                         end

`define ASSERT_TEST(x) assert(x == 1) passed_tests++; \
                         else begin \
                             failed_tests++; \
                             assert(0); \
                             return; \
                         end
                         
`define ASSERT(x) assert(x) else return;

                         
task get_resp_reg;
    input integer reg_num;
    output integer reg_val;
    begin
        assert(reg_num >= 0 && reg_num < 4);
        wbm_read(reg_addr(`resp0 + 4*reg_num), reg_val, 4'hF, 1, 0,
            $random%5);
    end
endtask

task test_send_cmd;
    integer status;
    begin

        ////////////////////////////////////////////////////////////////
        //                                                            //
        //  test_send_cmd:                                            //
        //                                                            //
        //  TEST 0: Send CMD0, No Response, All Error check           //   
        //                                                            //
        ////////////////////////////////////////////////////////////////

        setup_core(16'hffff, 16'hffff);
        
        send_cmd(0, 0, status);
        `ASSERT_CMD_STATUS(status)
        `ASSERT_TEST(status)
        
    end
endtask

task init_card;
    output integer status;
    output integer rca;
    integer resp_data;
    begin
        
        setup_core(16'h2ff, 16'hfff);
        
        //CMD 0 Reset card
        send_cmd(0, 0, status);
        `ASSERT_CMD_STATUS(status)

        //CMD 8. Get voltage (Only 2.0 Card response to this)
        send_cmd(`CMD8 | `RSP_48, 0, status);
        //if (status[`INT_CMD_EI] == 1)
        //    $display("  V 1.0 Card");       

        resp_data[31]=1; //Just to make it to not skip first 
        while (resp_data[31]) begin //Wait until busy is clear in the card
            //Send CMD 55
            send_cmd(`CMD55 |`CICE | `CRCE | `RSP_48, 0, status);
            `ASSERT_CMD_STATUS(status)

            //Send ACMD 41
            send_cmd(`ACMD41 | `RSP_48, 0, status);
            `ASSERT_CMD_STATUS(status)
            get_resp_reg(0, resp_data);
        end 

        //Send CMD 2
        send_cmd(`CMD2 | `CRCE | `RSP_136, 0, status);
        `ASSERT_CMD_STATUS(status)
        get_resp_reg(0, resp_data);
    
        //Send CMD 3
        send_cmd(`CMD3 |  `CRCE | `CRCE | `RSP_48, 0, status);
        `ASSERT_CMD_STATUS(status)
        get_resp_reg(0, resp_data);
        rca = resp_data[31:16];
        
    end
endtask

task test_init_sequnce;
    integer status;
    integer rca;
    begin

        ////////////////////////////////////////////////////////////////
        //                                                            // 
        //  test_init_sequnce:                                        //
        //                                                            //
        //  Test 1: Init sequence, With response check                //
        //  CMD 0. Reset Card                                         //
        //  CMD 8. Get voltage (Only 2.0 Card response to this)       //
        //  CMD55. Indicate Next Command are Application specific     //
        //  ACMD44. Get Voltage windows                               //
        //  CMD2. CID reg                                             //
        //  CMD3. Get RCA.                                            //
        //                                                            //
        ////////////////////////////////////////////////////////////////
        init_card(status, rca);
        `ASSERT_TEST(status)
        //$display("  RCA Nr for data transfer: %h", rca);
        
    end
endtask

task setup_card_to_transfer;
    input integer rca;
    output integer status;
    integer resp_data;
    begin
    
        //Put in transferstate
        //Send CMD 7
        send_cmd(`CMD7 |  `CRCE | `CRCE | `RSP_48, rca << 16, status);
        `ASSERT_CMD_STATUS(status)
       
        //Set bus width
        //Send CMD 55
        send_cmd(`CMD55 |`CICE | `CRCE | `RSP_48, 0, status);
        `ASSERT_CMD_STATUS(status)

        //Send ACMD 6
        send_cmd(`ACMD6 |`CICE | `CRCE | `RSP_48, 2, status);
        `ASSERT_CMD_STATUS(status)
        get_resp_reg(0, resp_data);
        //$display("  Card status after Bus width set %h", resp_data);
        
    end
endtask

task setup_dma;
    input integer addr;
    begin
        wbm_write(reg_addr(`dst_src_addr), addr, 4'hF, 1, 0, $random%5);
    end
endtask

task xfer_data;
    output integer status;
    begin
    
        //read data_isr
        status = 0;
        while (status[`INT_DATA_CC] != 1 && status[`INT_DATA_EI] != 1)
            wbm_read(reg_addr(`data_isr), status, 4'hf, 1, 0, $random%5);
        //clear data isr
        wbm_write(reg_addr(`data_isr), 0, 4'hF, 1, 0, $random%5);
        
    end
endtask

task send_cmd_with_data;
    input integer command;
    input integer argument;
    input integer dma_addr;
    output integer status;
    integer resp_data;
    begin
        setup_dma(dma_addr);
        
        send_cmd(command, argument, status);
        `ASSERT_CMD_STATUS(status)

        xfer_data(status);
        
    end
endtask

task init_card_to_transfer;
    output integer status;
    integer rca;
    begin
        init_card(status, rca);
        `ASSERT(status)
 
        setup_card_to_transfer(rca, status);
        `ASSERT(status)
        
    end
endtask

task test_send_data;
    integer status;
    integer resp_data;
    integer rca;
    begin

        ////////////////////////////////////////////////////////////////
        //                                                            // 
        //  TEST 2: Send data                                         //
        //  init card                                                 //
        //  CMD 7. Put Card in transfer state                         //
        //  CMD 55.                                                   //
        //  ACMD 6. Set bus width                                     //
        //  CMD 24. Send data                                         //
        //                                                            //
        ////////////////////////////////////////////////////////////////

        init_card_to_transfer(status);
        `ASSERT_TEST(status)
        
        send_cmd_with_data(`CMD17 | `CRD | `CICE | `CRCE | `RSP_48, 0, 0, status);
        `ASSERT_DATA_STATUS(status)
        `ASSERT_TEST(status)

    end
endtask

task test_send_rec_data;
    integer status;
    begin
  
        /////////////////////////////////////////////////////////////////
        //                                                             // 
        //  TEST 3: Send and receive data                              //
        //  init card                                                  //
        //  setup card for transfer                                    //
        //  CMD 24. Write data                                         //
        //  CMD 17. Read data                                          //
        //  CMD 12. Stop transfer                                      //
        //                                                             //
        /////////////////////////////////////////////////////////////////

        init_card_to_transfer(status);
        `ASSERT_TEST(status)
        
        send_cmd_with_data(`CMD24 | `CWD | `CICE | `CRCE | `RSP_48, 0, 0, status);
        `ASSERT_DATA_STATUS(status)
        `ASSERT_TEST(status)
        
        clear_memories;
        
        send_cmd_with_data(`CMD17 | `CRD | `CICE | `CRCE | `RSP_48, 0, 1, status);
        `ASSERT_DATA_STATUS(status)
        `ASSERT_TEST(status)

        send_cmd(`CMD12 |`CICE | `CRCE | `RSP_48, 0, status);
        `ASSERT_CMD_STATUS(status)
        `ASSERT_TEST(status)

    end
endtask

task test_send_cmd_error_rsp_impl;
    integer status;
    integer rca;
    begin
        send_cmd(`CMD16 | `RSP_48, 512, status);
        `ASSERT_CMD_STATUS(status)
        `ASSERT_TEST(status)

        send_cmd(`CMD16 | `CICE | `CRCE | `RSP_48, 512, status);
        `ASSERT_TEST(status[`INT_CMD_EI] == 1 && status[`INT_CMD_CCRCE] == 1 && status[`INT_CMD_CIE] == 1)

        send_cmd(`CMD16 | `CRCE | `RSP_48, 512, status);
        `ASSERT_TEST(status[`INT_CMD_EI] == 1 && status[`INT_CMD_CCRCE] == 1 && status[`INT_CMD_CIE] == 0)

    end
endtask

task test_send_cmd_error_rsp;
    integer status;
    integer rca;
    begin

        //////////////////////////////////////////////////////////////////
        //                                                              //
        //  Test 4: Send CMD with a simulated bus error                 //
        //  init card                                                   //
        //  all folowing responses with crc error and index error       //
        //  CMD 16. no error check                                       //
        //  CMD 16. with all error check                                 //
        //  CMD 16. with crc error check                                 //
        //                                                              //
        //////////////////////////////////////////////////////////////////

        init_card(status, rca);
        `ASSERT_TEST(status)
   
        sdModelTB0.add_wrong_cmd_crc<=1;
        sdModelTB0.add_wrong_cmd_indx<=1;
        
        test_send_cmd_error_rsp_impl;

        sdModelTB0.add_wrong_cmd_crc<=0;
        sdModelTB0.add_wrong_cmd_indx<=0;
        
    end
endtask

task test_send_rec_data_error_rsp_impl;
    integer status;
    begin
        send_cmd_with_data(`CMD24 | `CWD | `CICE | `CRCE | `RSP_48, 0, 0, status);
        `ASSERT_TEST(status[`INT_DATA_EI] == 1 && status[`INT_DATA_CCRCE] == 1)
        
        clear_memories;
        
        send_cmd_with_data(`CMD17 | `CRD | `CICE | `CRCE | `RSP_48, 0, 1, status);
        `ASSERT_TEST(status[`INT_DATA_EI] == 1 && status[`INT_DATA_CCRCE] == 1)

    end
endtask

task test_send_rec_data_error_rsp;
    integer status;
    begin

        //////////////////////////////////////////////////////////////////
        //                                                              // 
        //   Test 5: Send and receive data with error                   //  
        //                                                              //
        //////////////////////////////////////////////////////////////////

        init_card_to_transfer(status);
        `ASSERT_TEST(status)
        //TODO
        sdModelTB0.add_wrong_data_crc<=1;

        test_send_rec_data_error_rsp_impl;

        sdModelTB0.add_wrong_data_crc<=0;
        
    end
endtask

task wbm_write;
    input [31:0] address_i;
    input [31:0] data_i;
    input [3:0] sel_i;
    input [31:0] size_i;
    input [3:0] init_waits_i; //initial wait cycles between CYC_O and STB_O of WB Master
    input [3:0] subseq_waits_i; //subsequent wait cycles between STB_Os of WB Master
    
    reg `WRITE_STIM_TYPE write_data;
    reg `WB_TRANSFER_FLAGS flags;
    reg `WRITE_RETURN_TYPE write_status;
    integer i;
    begin
    
        wbm_working = 1;
        write_status = 0;

        flags = 0;
        flags`WB_TRANSFER_SIZE = size_i;
        flags`INIT_WAITS = init_waits_i;
        flags`SUBSEQ_WAITS = subseq_waits_i;

        write_data = 0;
        write_data`WRITE_DATA = data_i[31:0];
        write_data`WRITE_ADDRESS = address_i;
        write_data`WRITE_SEL = sel_i;

        for (i = 0; i < size_i; i = i + 1)
        begin
            wb_master0.blk_write_data[i] = write_data;
            data_i = data_i >> 32;
            write_data`WRITE_DATA = data_i[31:0];
            write_data`WRITE_ADDRESS = write_data`WRITE_ADDRESS + 4;
        end

        wb_master0.wb_block_write(flags, write_status);

        assert(write_status`CYC_ACTUAL_TRANSFER == size_i);

        @(posedge wb_clk);
        #3;
        wbm_working = 0;
        #1;
        
    end
endtask

task wbm_read;
    input [31:0] address_i;
    output [((`MAX_BLK_SIZE * 32) - 1):0] data_o;
    input [3:0] sel_i;
    input [31:0] size_i;
    input [3:0] init_waits_i; //initial wait cycles between CYC_O and STB_O of WB Master
    input [3:0] subseq_waits_i; //subsequent wait cycles between STB_Os of WB Master

    reg `READ_RETURN_TYPE read_data;
    reg `WB_TRANSFER_FLAGS flags;
    reg `READ_RETURN_TYPE read_status;
    integer i;
    begin
    
        wbm_working = 1;
        read_status = 0;
        data_o = 0;

        flags = 0;
        flags`WB_TRANSFER_SIZE = size_i;
        flags`INIT_WAITS = init_waits_i;
        flags`SUBSEQ_WAITS = subseq_waits_i;

        read_data = 0;
        read_data`READ_ADDRESS = address_i;
        read_data`READ_SEL = sel_i;

        for (i = 0; i < size_i; i = i + 1)
        begin
            wb_master0.blk_read_data_in[i] = read_data;
            read_data`READ_ADDRESS = read_data`READ_ADDRESS + 4;
        end

        wb_master0.wb_block_read(flags, read_status);

        assert(read_status`CYC_ACTUAL_TRANSFER == size_i);

        for (i = 0; i < size_i; i = i + 1)
        begin
            data_o = data_o << 32;
            read_data = wb_master0.blk_read_data_out[(size_i - 1) - i];
            data_o[31:0] = read_data`READ_DATA;
        end

        @(posedge wb_clk);
        #3;
        wbm_working = 0;
        #1;
        
    end
endtask


task clear_memories;
    reg [22:0] adr_i;
    reg delta_t;
    begin
        for (adr_i = 0; adr_i < 4194304; adr_i = adr_i + 1)
            wb_slave0.wb_memory[adr_i[21:2]] = 0;
    end
endtask

task hard_reset;
    begin
    wb_rst = 1'b1;
    #TCLK;
    wb_rst = 1'b0;
    end
endtask

endmodule
