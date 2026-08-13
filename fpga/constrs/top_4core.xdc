###############################################################################
# Clock: 50 MHz
###############################################################################

set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 20.000 \
    -waveform {0.000 10.000} [get_ports clk]

###############################################################################
# Active-low reset: onboard RESET button
###############################################################################

set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports rst]

###############################################################################
# Program-success indicator: original LED1
###############################################################################

set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports succ]

###############################################################################
# UART: same physical pins, new four-core port names
###############################################################################

set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports uart_rx]

###############################################################################
# PWM: preserve original LED mappings
#
# LED2 = PWM_o[0]
# LED3 = PWM_o[1]
# LED4 = PWM_o[2]
###############################################################################

set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} \
    [get_ports {PWM_o[0]}]

set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} \
    [get_ports {PWM_o[1]}]

set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} \
    [get_ports {PWM_o[2]}]

# New fourth PWM output: J10 pin 3
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} \
    [get_ports {PWM_o[3]}]

###############################################################################
# I2C: same LM75 pins, new four-core port names
###############################################################################

set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports i2c_scl]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33} [get_ports i2c_sda]

set_property PULLUP true [get_ports i2c_scl]
set_property PULLUP true [get_ports i2c_sda]

###############################################################################
# UART debugger: same KEY1 pin, new four-core port name
###############################################################################

set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} \
    [get_ports uart_debug_en]

###############################################################################
# New four-core selector
#
# KEY2 = chip_sel[0]
# KEY3 = chip_sel[1]
# KEY4 = chip_sel[2]
#
# AX7035 keys are active low.
###############################################################################

set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} \
    [get_ports {chip_sel[0]}]

set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} \
    [get_ports {chip_sel[1]}]

set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} \
    [get_ports {chip_sel[2]}]

###############################################################################
# New "over" output: J10 pin 4
###############################################################################

set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports over]

###############################################################################
# Configuration voltage
###############################################################################

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
