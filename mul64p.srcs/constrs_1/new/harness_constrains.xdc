# Based on https://github.com/tomverbeure/kv260_bringup/blob/main/kv260_pinout.py

# Clock (507 MHz) - Using HDA16_CC which is available with LVCMOS33
set_property PACKAGE_PIN E12 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 1.971 -name clk [get_ports clk]

# Reset - Using HDA15 which is available with LVCMOS33
set_property PACKAGE_PIN B10 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# Serial input - Using HDA12 which is available with LVCMOS33
set_property PACKAGE_PIN E10 [get_ports serial_in]
set_property IOSTANDARD LVCMOS33 [get_ports serial_in]

# Data valid - Using HDA13 which is available with LVCMOS33
set_property PACKAGE_PIN D10 [get_ports data_valid]
set_property IOSTANDARD LVCMOS33 [get_ports data_valid]

# Result bit - Using HDA14 which is available with LVCMOS33
set_property PACKAGE_PIN C11 [get_ports result_bit]
set_property IOSTANDARD LVCMOS33 [get_ports result_bit]