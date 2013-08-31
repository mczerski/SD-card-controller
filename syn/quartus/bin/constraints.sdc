create_clock -period 50MHz -name wb_clk_i [get_ports {wb_clk_i}]
create_generated_clock -name sd_clk -source {wb_clk_i} -divide_by 2 [get_registers {sdc_controller:sdc_controller0|sd_clock_divider:clock_divider0|SD_CLK_O}]
derive_clock_uncertainty
set_false_path -from wb_clk_i -to sd_clk