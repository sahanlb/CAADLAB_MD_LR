# Copyright (C) 1991-2015 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, the Altera Quartus II License Agreement,
# the Altera MegaCore Function License Agreement, or other 
# applicable license agreement, including, without limitation, 
# that your use is for the sole purpose of programming logic 
# devices manufactured by Altera and sold by Altera or its 
# authorized distributors.  Please refer to the applicable 
# agreement for further details.

# Quartus II: Generate Tcl File for Project
# File: many_poor_processor_DE5_net.tcl
# Generated on: Sat Jan 25 19:31:38 2020

# Load Quartus II Tcl Project package
package require ::quartus::project

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "md_lr_top"]} {
		puts "Project md_lr_top is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists md_lr_top]} {
		project_open -revision md_lr_top md_lr_top
	} else {
		project_new -revision md_lr_top md_lr_top
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
	set_global_assignment -name FAMILY "Stratix 10"
	set_global_assignment -name DEVICE 1SX280HN2F43E2VG
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
	set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
	#set_global_assignment -name EDA_SIMULATION_TOOL "ModelSim-Altera (Verilog)"
  #set_global_assignment -name EDA_OUTPUT_DATA_FORMAT "VERILOG HDL" -section_id eda_simulation
	set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
	set_global_assignment -name MAX_CORE_JUNCTION_TEMP 100
	set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
	set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
  #set_global_assignment -name OPTIMIZATION_MODE "OPTIMIZE NETLIST FOR ROUTABILITY"
  #set_global_assignment -name FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION ALWAYS
  # set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE PERFORMANCE"

# Text macros
set_global_assignment -name VERILOG_MACRO "IS_AFU"

# Source Files

set_global_assignment -name IP_FILE ../ip/FpMul/FpMul.ip
set_global_assignment -name IP_FILE ../ip/FpSub/FpSub.ip
set_global_assignment -name IP_FILE ../ip/toFp/toFp.ip
set_global_assignment -name IP_FILE ../ip/fftIP/fftIP.ip
set_global_assignment -name IP_FILE ../ip/FpAdd/FpAdd.ip
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/md_lr_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/clustered_greens_rom.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/cfg_sp_ro_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/cfg_2p_1r1w_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/cfg_sp_rw_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/clustered_grid_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/coeffgen_3rdo.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/customdelay.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/md_lr_seqr.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/md_lr_top.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/Reduction_Tree.sv

set_global_assignment -name SDC_FILE ./md_lr_top.sdc

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
