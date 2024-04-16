#!/bin/bash

quartus_sh -t md_lr_top.tcl

quartus_sh -t run_synth.tcl

quartus_fit RL_top

quartus_sta RL_top
