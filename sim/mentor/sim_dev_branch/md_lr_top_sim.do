# ----------------------------------------
# # TOP-LEVEL TEMPLATE - BEGIN
# #
# # QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# # construct paths to the files required to simulate the IP in your Quartus
# # project. By default, the IP script assumes that you are launching the
# # simulator from the IP script location. If launching from another
# # location, set QSYS_SIMDIR to the output directory you specified when you
# # generated the IP script, relative to the directory from which you launch
# # the simulator.
# #
set QSYS_SIMDIR ../../
# #
# # Source the generated IP simulation script.
source $QSYS_SIMDIR/mentor/msim_setup.tcl
# #
# # Set any compilation options you require (this is unusual).
# set USER_DEFINED_COMPILE_OPTIONS <compilation options>
# set USER_DEFINED_VHDL_COMPILE_OPTIONS <compilation options for VHDL>
set USER_DEFINED_VERILOG_COMPILE_OPTIONS +acc=npr
# #
# # Call command to compile the Quartus EDA simulation library.
#dev_com
# #
# # Call command to compile the Quartus-generated IP simulation files.
#com
# #
# # Add commands to compile all design files and testbench files, including
# # the top level. (These are all the files required for simulation other
# # than the files compiled by the Quartus-generated IP simulation script)
# #
# vlog <compilation options> <design and testbench files>
#vlog +acc=npr ../../../rtl/md_lr_pkg.sv
vlog +acc=npr -suppress 2600 ../../../rtl/Reduction_Tree.sv
vlog +acc=npr -suppress 2600 ../../../rtl/cfg_2p_1r1w_mem.sv
vlog +acc=npr -suppress 2600 ../../../rtl/cfg_sp_ro_mem.sv
vlog +acc=npr -suppress 2600 ../../../rtl/cfg_sp_rw_mem.sv
vlog +acc=npr -suppress 2600 ../../../rtl/clustered_greens_rom.sv
vlog +acc=npr -suppress 2600 ../../../rtl/clustered_grid_mem.sv
vlog +acc=npr -suppress 2600 ../../../rtl/coeffgen_3rdo.sv
vlog +acc=npr -suppress 2600 ../../../rtl/customdelay.sv
vlog +acc=npr -suppress 2600 ../../../rtl/md_lr_seqr.sv
vlog +acc=npr -suppress 2600 ../../../rtl/md_lr_top.sv
vlog +acc=npr -suppress 2600 -timescale 1ns/1ns ../../../ip/resetRelease/resetRelease/resetRelease_bb.v
vlog +acc=npr -suppress 2600 -timescale 1ns/1ns +incdir+../../../tb/include +incdir+../../../rtl ../../../tb/md_lr_top_tb.sv

# #
# # Set the top-level simulation or testbench module/entity name, which is
# # used by the elab command to elaborate the top level.
# #
set TOP_LEVEL_NAME md_lr_top_tb
# #
# # Set any elaboration options you require.
#set USER_DEFINED_ELAB_OPTIONS <elaboration options>
# #
# # Call command to elaborate your design and testbench.
elab
# #
# # Run the simulation.
add wave -depth 25 * 
view structure
view signals
#run -a
#run 500us 
run 1000000ns
# #
# # Report success to the shell.
exit -code 0
# #
# # TOP-LEVEL TEMPLATE - END
# ----------------------------------------
