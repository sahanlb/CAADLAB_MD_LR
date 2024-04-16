
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

proc get_common_design_files {QSYS_SIMDIR} {
  set design_files [dict create]
  return $design_files
}

proc get_design_files {QSYS_SIMDIR} {
  set design_files [dict create]
  error "Skipping VCS script generation since VHDL file $QSYS_SIMDIR/../ip/FpAdd/FpAdd/altera_fp_functions_181/sim/dspba_library_package.vhd is required for simulation"
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


