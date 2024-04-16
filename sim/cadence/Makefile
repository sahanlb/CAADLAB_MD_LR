## ============================================================================
##
## Original Author: aducimo
## Filename       : Makefile
## Description    : Lint Makefile
## 
## ============================================================================

##-----------------------------------------------------------------------------
## make target default : help
##-----------------------------------------------------------------------------
default: help

##-----------------------------------------------------------------------------
## make target help : generates help message
##-----------------------------------------------------------------------------
help:
	@echo "Targets are:";
	@echo " help                            : prints this help message";
	@echo " sim_mod MOD=<mod> WAVES=<waves> : Invokes Cadence Xcelium to simulate module in its designated testbench";
	@echo "  <mod>                          : Name of module to be simulated";
	@echo "  <waves>                        : Waveform capture enable [ON|OFF], default OFF";
	@echo " clean_mod MOD=<mod>             : Cleans up lint data for specific module";
	@echo "  <mod>                          : Name of module whose simulation data is to be cleaned";
	@echo " clean_all                       : Cleans all sim generated data";
	@echo "-------------------------------------------------------------------------------";
	@echo "Valid Modules w/ Options:";
	@echo "  ////////////////////////";
	@echo "  // clustered_grid_mem //";
	@echo "  ////////////////////////";
	@echo "  //";
	@echo "  ///////////////";
	@echo "  // md_lr_top //";
	@echo "  ///////////////";
	@echo "  //";
##-----------------------------------------------------------------------------
# Set configuration if not set at command line
GSIZE1D ?= 32
NNN1D   ?= 4
GELEW   ?= 64
BRDTYPE ?= 0
RGRDATA ?= 0

##-----------------------------------------------------------------------------
# Determine name of sandbox. It's the parent of the current working directory
SNDBXSIM = $(shell pwd | rev | cut -d '/' -f 1-3 | rev)

##-----------------------------------------------------------------------------
# Set sandbox directories directory
SNDPATH = $(shell pwd | rev | cut -c 13- | rev)
IPDIR   = ${SNDPATH}/ip
INCDIR  = ${SNDPATH}/include
RTLDIR  = ${SNDPATH}/rtl

##-----------------------------------------------------------------------------
# Set output directory

OUTDIRP = /projects/nobkup/dr949/${USER}/${SNDBXSIM}

OUTDIR  = ${OUTDIRP}/${MOD}

##-----------------------------------------------------------------------------
# Logfile name
ifeq (${MOD},clustered_grid_mem)
  NME = ${MOD}_${GSIZE1D}GSIZE1D_${NNN1D}NNN1D_${GELEW}GELEW_${BRDTYPE}BRDTYPE_${RGRDATA}RGRDATA
else ifeq (${MOD},distributed_grid_mem)
  NME = ${MOD}_${GSIZE1D}GSIZE1D_${NNN1D}NNN1D_${GELEW}GELEW_${BRDTYPE}BRDTYPE_${RGRDATA}RGRDATA
else
  NME = ${MOD}
endif

##-----------------------------------------------------------------------------
# Output Logfiles
SIMLOG = ${OUTDIR}/${NME}.xrun.log

##########
# Shared #
##########
#
${MOD}_CPRE  = $(subst -incdir,,${${MOD}_INC})
${MOD}_CPRE += $(subst -incdir,,${${MOD}_TB_INC})
${MOD}_CPRE += ${${MOD}_HDL}
${MOD}_CPRE += ${${MOD}_TB}

###################
# cfg_2p_1r1w_mem #
###################
#
cfg_2p_1r1w_mem_HDL  = ${SNDPATH}/rtl/cfg_2p_1r1w_mem.sv

#################
# cfg_sp_rw_mem #
#################
#
cfg_sp_rw_mem_HDL  = ${SNDPATH}/rtl/cfg_sp_rw_mem.sv

######################
# clustered_grid_mem #
######################
#
clustered_grid_mem_HDL  = ${cfg_2p_1r1w_mem_HDL}
clustered_grid_mem_HDL += ${SNDPATH}/rtl/clustered_grid_mem.sv

clustered_grid_mem_TB = ${SNDPATH}/tb/clustered_grid_mem_tb.sv

# Configuration arguments

########################
# distributed_grid_mem #
########################
#
distributed_grid_mem_HDL  = ${cfg_sp_rw_mem_HDL}
distributed_grid_mem_HDL += ${SNDPATH}/rtl/distributed_grid_mem.sv

distributed_grid_mem_TB = ${SNDPATH}/tb/distributed_grid_mem_tb.sv

# Configuration arguments

##############
# md_lr_seqr #
##############
#
md_lr_seqr_HDL  = ${SNDPATH}/rtl/md_lr_seqr.sv

md_lr_seqr_INC = -incdir ${SNDPATH}/rtl

###########
# coeff64 #
###########
#
coeff64_HDL  = ${SNDPATH}/rtl/coeff64.sv
coeff64_HDL += ${SNDPATH}/ip/FpAdd/FpAdd/FpAdd_bb.v
coeff64_HDL += ${SNDPATH}/ip/FpMul/FpMul/FpMul_bb.v
coeff64_HDL += ${SNDPATH}/rtl/customdelay.sv
coeff64_HDL += ${SNDPATH}/ip/toFp/toFp/toFp_bb.v

#############
# md_lr_top #
#############
#
md_lr_top_HDL  = ${cfg_sp_rw_mem_HDL}
md_lr_top_HDL += ${clustered_grid_mem_HDL}
md_lr_top_HDL += ${coeffgen_3rdo_HDL}
md_lr_top_HDL += ${md_lr_seqr_HDL}
md_lr_top_HDL += ${SNDPATH}/rtl/md_lr_top.sv
md_lr_top_HDL += ${SNDPATH}/rtl/Reduction_Tree.sv
md_lr_top_HDL += ${SNDPATH}/ip/fftIP/fftIP/fftIP_bb.v
md_lr_top_HDL += ${SNDPATH}/ip/ifftIP/ifftIP/ifftIP_bb.v

md_lr_top_INC  = ${md_lr_seqr_INC}
md_lr_top_INC += -incdir ${SNDPATH}/tb/include

md_lr_top_TB = ${SNDPATH}/tb/md_lr_top_tb.sv

# Configuration arguments

#################
# coeffgen_3rdo #
#################
#
coeffgen_3rdo_HDL  = ${SNDPATH}/rtl/coeffgen_3rdo.sv
coeffgen_3rdo_HDL += ${SNDPATH}/ip/FpAdd/FpAdd/FpAdd_bb.v
coeffgen_3rdo_HDL += ${SNDPATH}/ip/FpMul/FpMul/FpMul_bb.v
coeffgen_3rdo_HDL += ${SNDPATH}/rtl/customdelay.sv
coeffgen_3rdo_HDL += ${SNDPATH}/ip/toFp/toFp/toFp_bb.v

#################
# fft_ring_ntwk #
#################
#
fft_ring_ntwk_HDL  = ${SNDPATH}/rtl/fft_ring_pkg.sv
fft_ring_ntwk_HDL += ${SNDPATH}/rtl/fft_ring_node.sv

fft_ring_ntwk_INC = -incdir ${SNDPATH}/rtl

fft_ring_ntwk_TB = ${SNDPATH}/tb/fft_ring_ntwk_tb.sv

##-----------------------------------------------------------------------------
# Design Simulation Command
#
SIMCMD  = module load xcelium/19.03.002;
SIMCMD += xrun -sv -64bit -timescale 1ns/100ps
SIMCMD += -nowarn DSEMEL
SIMCMD += -access +rwc
SIMCMD += -snapshot ${MOD}:sv
SIMCMD += -xmlibdirpath ${OUTDIR}
SIMCMD += -l ${SIMLOG}
SIMCMD += -F ${OUTDIR}/${MOD}_hdl.f

ifeq (${WAVES},ON)
  SIMCMD += -input ${OUTDIR}/wave.tcl
endif

ifeq (${${MOD}_VEND},)
  SIMCMD += ;
else
  SIMCMD += -F ${OUTDIR}/${MOD}_vendors.f;
endif

QSIMCMD  = qrsh -q sim.q -o /dev/null -pty y -j y -b y -cwd 
QSIMCMD += -now no -N MDLR_SIM "hostname; ${SIMCMD}"

##-----------------------------------------------------------------------------
## ${OUTDIR} : Create output directory
##-----------------------------------------------------------------------------
${OUTDIR} :
	@mkdir -p ${OUTDIR}

##-----------------------------------------------------------------------------
## make target sim_mod: Compile and elaborate module
##-----------------------------------------------------------------------------
sim_mod : ${SIMLOG}

${SIMLOG} : ${${MOD}_CPRE} | ${OUTDIR} ${OUTDIR}/wave.tcl
# Determine module to be simulated.
# A valid module has a non-empty set of prerequisite files
ifeq (${${MOD}_CPRE},)
	$(error "${MOD} is an invalid module. Please specify a valid module")
endif
	@mkdir -p ${OUTDIR}
	@echo "" > ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_INC} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_HDL} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_TB_INC} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_TB} >> ${OUTDIR}/${MOD}_hdl.f
	@echo ${${MOD}_CFGARGS} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" > ${OUTDIR}/${MOD}_vendors.f
	@echo ${${MOD}_VEND} >> ${OUTDIR}/${MOD}_vendors.f
	${QSIMCMD}

${OUTDIR}/wave.tcl: | ${OUTDIR}
	@echo "database -open -shm wave -default -event" > $@
	@echo "probe -create -database wave ${MOD}_tb -all -memories -depth all" >> $@
	@echo "run" >> $@
	@echo "exit" >> $@

#-----------------------------------------------------------------------------
## Clean-Up Targets: 
##-----------------------------------------------------------------------------
clean_mod :
# Determine module whose sim data needs to be cleaned.
# A valid module has a non-empty set of prerequisite files
ifeq (${${MOD}_CPRE},)
	$(error "${MOD} is an invalid module. Please specify a valid module")
endif
	rm -rf ${OUTDIR}

clean_all :
	rm -rf ${OUTDIRP}
