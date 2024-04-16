
proc get_design_libraries {} {
  set libraries [dict create]
  dict set libraries altera_fp_functions_181         1
  dict set libraries FpAdd                           1
  dict set libraries FpMul                           1
  dict set libraries FpSub                           1
  dict set libraries altera_fft_ii_181               1
  dict set libraries fftIP                           1
  dict set libraries altera_s10_user_rst_clkgate_181 1
  dict set libraries resetRelease                    1
  dict set libraries toFp                            1
  return $libraries
}

proc get_memory_files {QSYS_SIMDIR} {
  set memory_files [list]
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq_twifp1.hex"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq_twqfp1.hex"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq_twrfp1.hex"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/test_data/fftIP_altera_fft_ii_181_iruogdq_blksize_report.txt"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/test_data/fftIP_altera_fft_ii_181_iruogdq_inverse_report.txt"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/test_data/fftIP_altera_fft_ii_181_iruogdq_imag_input.txt"
  lappend memory_files "$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/test_data/fftIP_altera_fft_ii_181_iruogdq_real_input.txt"
  return $memory_files
}

proc get_common_design_files {USER_DEFINED_COMPILE_OPTIONS USER_DEFINED_VERILOG_COMPILE_OPTIONS USER_DEFINED_VHDL_COMPILE_OPTIONS QSYS_SIMDIR} {
  set design_files [dict create]
  return $design_files
}

proc get_design_files {USER_DEFINED_COMPILE_OPTIONS USER_DEFINED_VERILOG_COMPILE_OPTIONS USER_DEFINED_VHDL_COMPILE_OPTIONS QSYS_SIMDIR} {
  set design_files [list]
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpAdd/FpAdd/altera_fp_functions_181/sim/dspba_library_package.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpAdd/FpAdd/altera_fp_functions_181/sim/dspba_library.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpAdd/FpAdd/altera_fp_functions_181/sim/FpAdd_altera_fp_functions_181_2ezb4pq.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                             
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpAdd/FpAdd/sim/FpAdd.v\"  -work FpAdd"                                                                                                                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpMul/FpMul/altera_fp_functions_181/sim/dspba_library_package.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpMul/FpMul/altera_fp_functions_181/sim/dspba_library.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpMul/FpMul/altera_fp_functions_181/sim/FpMul_altera_fp_functions_181_yr5r2ii.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                             
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpMul/FpMul/sim/FpMul.v\"  -work FpMul"                                                                                                                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpSub/FpSub/altera_fp_functions_181/sim/dspba_library_package.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpSub/FpSub/altera_fp_functions_181/sim/dspba_library.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpSub/FpSub/altera_fp_functions_181/sim/FpSub_altera_fp_functions_181_maytsbq.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                             
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/FpSub/FpSub/sim/FpSub.v\"  -work FpSub"                                                                                                                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/auk_dspip_text_pkg.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                  
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/auk_dspip_math_pkg.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                  
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/auk_dspip_lib_pkg.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                   
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/auk_dspip_avalon_streaming_block_sink.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                       
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/auk_dspip_avalon_streaming_block_source.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/auk_dspip_roundsat.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                  
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/hyper_opt_OFF_pkg.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/auk_dspip_avalon_streaming_block_sink_fftfprvs.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                              
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/altera_fft_mult_add.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/altera_fft_dual_port_ram.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                    
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/altera_fft_dual_port_rom.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                    
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/auk_fft_pkg.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                 
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/altera_fft_single_port_rom.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                  
  lappend design_files "ncvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/hyper_pipeline_interface.v\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                        
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/counter_module.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_fft4.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_top.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfpbdr_top.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_stage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfpbdr_core.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_ram.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_hcc_cntsgn32.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_lsft32.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_unorm.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfpbdr_firststage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_laststage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                      
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_mul_2727.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                          
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_mul.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_top.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_shift.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_twiddle_opt.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                       
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_hcc_sgnpstn.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_rvsctl.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfpbdr_laststage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                      
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_snorm_mul.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_fft4.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                              
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_add.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_twiddle.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_core.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                              
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_sub.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_stage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                          
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_twiddle_opt.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                    
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_laststage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_hcc_cntusgn32.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_snorm.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_hcc_usgnpos.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                             
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_del.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfpbdr_stage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                          
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_core.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                           
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_rvs.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_cmplxmult.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfprvs_firststage.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                     
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_dft4.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                              
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/cadence/apn_fftfp_rsft32.vhd\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                            
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                    
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/avalon_utilities_pkg.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                               
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/verbosity_pkg.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                                      
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/altera_avalon_clock_source.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/altera_avalon_reset_source.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                         
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/altera_avalon_st_source_bfm.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                        
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/altera_avalon_st_sink_bfm.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                          
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq_tb.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                                 
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/altera_fft_ii_181/sim/fftIP_altera_fft_ii_181_iruogdq_test_program.sv\"  -work altera_fft_ii_181 -cdslib  ./cds_libs/altera_fft_ii_181.cds.lib"                                       
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/fftIP/fftIP/sim/fftIP.v\"  -work fftIP"                                                                                                                                                     
  lappend design_files "ncvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/resetRelease/resetRelease/altera_s10_user_rst_clkgate_181/sim/altera_s10_user_rst_clkgate.sv\"  -work altera_s10_user_rst_clkgate_181 -cdslib  ./cds_libs/altera_s10_user_rst_clkgate_181.cds.lib"
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/resetRelease/resetRelease/sim/resetRelease.v\"  -work resetRelease"                                                                                                                         
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/toFp/toFp/altera_fp_functions_181/sim/dspba_library_package.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                               
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/toFp/toFp/altera_fp_functions_181/sim/dspba_library.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                                       
  lappend design_files "ncvhdl -v93 $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/toFp/toFp/altera_fp_functions_181/sim/toFp_altera_fp_functions_181_2kywi7q.vhd\"  -work altera_fp_functions_181 -cdslib  ./cds_libs/altera_fp_functions_181.cds.lib"                                
  lappend design_files "ncvlog -compcnfg $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"$QSYS_SIMDIR/../ip/toFp/toFp/sim/toFp.v\"  -work toFp"                                                                                                                                                         
  return $design_files
}

proc get_elab_options {SIMULATOR_TOOL_BITNESS} {
  set ELAB_OPTIONS ""
  if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
  } else {
  }
  return $ELAB_OPTIONS
}


proc get_sim_options {SIMULATOR_TOOL_BITNESS} {
  set SIM_OPTIONS ""
  if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
  } else {
  }
  return $SIM_OPTIONS
}


proc get_env_variables {SIMULATOR_TOOL_BITNESS} {
  set ENV_VARIABLES [dict create]
  set LD_LIBRARY_PATH [dict create]
  dict set ENV_VARIABLES "LD_LIBRARY_PATH" $LD_LIBRARY_PATH
  if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
  } else {
  }
  return $ENV_VARIABLES
}


