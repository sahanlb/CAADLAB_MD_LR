## ============================================================================
##
## Original Author: Anthony Ducimo
## Filename       : md_lr_top.sdc
## Description    : Constraints for md_lr_top
## 
## ============================================================================

## ============================================================================
## Clocks
## ============================================================================
create_clock -name CLK -period 10 -waveform {0.0 5} [get_ports clk]

## ============================================================================
## IOs
## ============================================================================
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports pvalid]
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports paddr*]
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports pwe]
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports pwdata*]
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports plast]
set_input_delay -add_delay -max 2.5 -clock CLK [get_ports fready]

set_input_delay -add_delay -min 0 -clock CLK [get_ports pvalid]
set_input_delay -add_delay -min 0 -clock CLK [get_ports paddr*]
set_input_delay -add_delay -min 0 -clock CLK [get_ports pwe]
set_input_delay -add_delay -min 0 -clock CLK [get_ports pwdata*]
set_input_delay -add_delay -min 0 -clock CLK [get_ports plast]
set_input_delay -add_delay -min 0 -clock CLK [get_ports fready]

set_output_delay -add_delay -max 2.5 -clock CLK [get_ports pready]
set_output_delay -add_delay -max 2.5 -clock CLK [get_ports fvalid]
set_output_delay -add_delay -max 2.5 -clock CLK [get_ports faddr*]
set_output_delay -add_delay -max 2.5 -clock CLK [get_ports flast]
set_output_delay -add_delay -max 2.5 -clock CLK [get_ports fdata*]

set_output_delay -add_delay -min 0 -clock CLK [get_ports pready]
set_output_delay -add_delay -min 0 -clock CLK [get_ports fvalid]
set_output_delay -add_delay -min 0 -clock CLK [get_ports faddr*]
set_output_delay -add_delay -min 0 -clock CLK [get_ports flast]
set_output_delay -add_delay -min 0 -clock CLK [get_ports fdata*]
