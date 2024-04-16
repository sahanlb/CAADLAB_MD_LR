## ============================================================================
##
## Original Author: Anthony Ducimo
## Filename       : wrapped_md_lr_top.sdc
## Description    : Constraints for wrapped_md_lr_top
## 
## ============================================================================

## ============================================================================
## Clocks
## ============================================================================
create_clock -name CLK -period 2 -waveform {0.0 1} [get_ports clk]

## ============================================================================
## IOs
## ============================================================================
#set_output_delay -add_delay -max 1.25 -clock CLK [get_ports f*xor]

#set_output_delay -add_delay -min -1.25 -clock CLK [get_ports f*xor]

set_false_path -from CLK -to [get_ports f*xor]

set_multicycle_path -setup 10 -through [get_pins DUT|u_md_lr_seqr|fft_reset_n|q]
