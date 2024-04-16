## ============================================================================
##
## Original Author: Anthony Ducimo
## Filename       : md_lr_top_io_fp.sdc
## Description    : Constraints for md_lr_top
## 
## ============================================================================

## ============================================================================
## Clocks
## ============================================================================
create_clock -name CLK -period 2 -waveform {0.0 1} [get_ports clk]

## ============================================================================
## IOs
## ============================================================================
set_false_path -from [get_ports pvalid]
set_false_path -from [get_ports paddr*]
set_false_path -from [get_ports pwe]
set_false_path -from [get_ports pwdata*]
set_false_path -from [get_ports plast]
set_false_path -from [get_ports fready]

set_false_path -to [get_ports pready]
set_false_path -to [get_ports fvalid]
set_false_path -to [get_ports faddr*]
set_false_path -to [get_ports flast]
set_false_path -to [get_ports fdata*]

set_multicycle_path -setup 10 -through [get_pins u_md_lr_seqr|fft_reset_n|q]
