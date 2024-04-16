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
	@echo " help                    : prints this help message";
	@echo " ce_mod    MOD=<mod>     : Invokes Cadence Xcelium to compile and elaborate specified module";
	@echo "  <mod>                  : Name of module to be linted";
	@echo " lint_mod  MOD=<mod>     : Invokes Cadence HAL to run lint on specified module";
	@echo "  <mod>                  : Name of module to be linted";
	@echo " scan_mod_lint MOD=<mod> : Runs scanlogs on module that has been linted";
	@echo "  <mod>                  : Name of module whose logs are to be scanned";
	@echo " regress_cgm             : Runs lint regression over representative set of";
	@echo "                         : clustered_grid_mem configs";
	@echo " clean_mod MOD=<mod>     : Cleans up lint data for specific module";
	@echo "  <mod>                   Name of module whose lint data is to be cleaned";
	@echo " clean_all               : Cleans all lint generated data";
	@echo "-------------------------------------------------------------------------------";
	@echo "Valid Modules w/ Options:";
	@echo "  ///////////////////";
	@echo "  // cfg_sp_rw_mem //";
	@echo "  ///////////////////";
	@echo "  //";
	@echo "  [BLKS=<blks>][BDEPTH=<bdepth>][SEGS=<segs>][SEGW=<segw>][RDTYPE=<rdtype>]";
	@echo "  <blks>   : Number of memory blocks";
	@echo "           :   0 < blks       , default 1";
	@echo "  <bdepth> : Number of array entries in a block";
	@echo "           :   0 < bdepth     , default 1";
	@echo "  <segs>   : Number of segments in an array entry";
	@echo "           :   0 < segs       , default 1";
	@echo "  <segw>   : Bit-width of an array entry segment";
	@echo "           :   0 < segw       , default 1";
	@echo "  <rdtype> : Read delay timing";
	@echo "           :   0 <= rdtype < 4, default 0";
	@echo "";
	@echo "  ///////////////////";
	@echo "  // cfg_sp_ro_mem //";
	@echo "  ///////////////////";
	@echo "  //";
	@echo "  [BLKS=<blks>][BDEPTH=<bdepth>][SEGS=<segs>][SEGW=<segw>][RDTYPE=<rdtype>]";
	@echo "  <blks>   : Number of memory blocks";
	@echo "           :   0 < blks       , default 1";
	@echo "  <bdepth> : Number of array entries in a block";
	@echo "           :   0 < bdepth     , default 1";
	@echo "  <segs>   : Number of segments in an array entry";
	@echo "           :   0 < segs       , default 1";
	@echo "  <segw>   : Bit-width of an array entry segment";
	@echo "           :   0 < segw       , default 1";
	@echo "  <rdtype> : Read delay timing";
	@echo "           :   0 <= rdtype < 4, default 0";
	@echo "";
	@echo "  /////////////////////";
	@echo "  // cfg_2p_1r1w_mem //";
	@echo "  /////////////////////";
	@echo "  //";
	@echo "  [BLKS=<blks>][BDEPTH=<bdepth>][SEGS=<segs>][SEGW=<segw>][RDTYPE=<rdtype>]";
	@echo "  <blks>   : Number of memory blocks";
	@echo "           :   0 < blks       , default 1";
	@echo "  <bdepth> : Number of array entries in a block";
	@echo "           :   0 < bdepth     , default 1";
	@echo "  <segs>   : Number of segments in an array entry";
	@echo "           :   0 < segs       , default 1";
	@echo "  <segw>   : Bit-width of an array entry segment";
	@echo "           :   0 < segw       , default 1";
	@echo "  <rdtype> : Read delay timing";
	@echo "           :   0 <= rdtype < 4, default 0";
	@echo "";
	@echo "  ////////////////////////";
	@echo "  // clustered_grid_mem //";
	@echo "  ////////////////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][NNN1D=<nnn1d>][GELEW=<gelew>][BRDTYPE=<brdtype>]";
	@echo "  <gsize1d*> : Size of one dimension of the grid";
	@echo "            :   0 < gsize1d   , default 32";
	@echo "  <nnn1d>   : Number of nearest neighbors along one dimension";
	@echo "            :   0 < nnn1d     , default 4";
	@echo "  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/";
	@echo "  Constraint: gsize1d Should be an integer multiple of nnn1d";
	@echo "  /\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\";
	@echo "  <gelew>   : Bit width of each grid element";
	@echo "            :   0 < gelew       , default 64";
	@echo "  <brdtype> : Read delay timing of grid mem blocks";
	@echo "            :   0 <= brdtype < 4, default 0";
	@echo "";
	@echo "  ////////////////";
	@echo "  // md_lr_seqr //";
	@echo "  ////////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][MAXNUMP=<maxnump>][NNN1D=<nnn1d>][PMRDTYPE=<pmrdtype>][GMRDTYPE=<gmrdtype>][FPADDDEL=<fpadddel>][GRNDEL=<grndel>][FPVW=<fpvw>]";
	@echo "  <gsize1d*> : Size of one dimension of the grid";
	@echo "             :   0 < gsize1d   , default 32";
	@echo "  <maxnump>  : Maximum number of particles";
	@echo "             : integer > 0     , default 32768";
	@echo "  <nnn1d>    : Number of nearest neighbors along one dimension";
	@echo "             :   0 < nnn1d     , default 4";
	@echo "  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/";
	@echo "  Constraints:  1) gsize1d Should be an integer multiple of nnn1d";
	@echo "             :  2) gsize1d, maxnump, and nnn1d should be a power of 2";
	@echo "             :  3) maxnump >= gsize1d*gsize1d*gsize1d";
	@echo "  /\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\";
	@echo "  <gmrdtype>  : Read delay timing of grid mem blocks";
	@echo "              :   0 <= gmrdtype < 4, default 2";
	@echo "  <pmrdtype>  : Read delay timing of particle mem blocks";
	@echo "              :   0 <= pmrdtype < 4, default 2";
	@echo "  <fpadddel>  : Latency of floating point addition";
	@echo "              :   integer >= 0    , default 5";
	@echo "  <grndel>    : Latency of Green's function";
	@echo "              :   integer > 0     , default 5";
	@echo "  <fpvw>      : Width of floating point values";
	@echo "              :   integer > 0     , default 32";
	@echo "";
	@echo "  ///////////////";
	@echo "  // md_lr_top //";
	@echo "  ///////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][MAXNUMP=<maxnump>][NNN1D=<nnn1d>][PMRDTYPE=<pmrdtype>][GMRDTYPE=<gmrdtype>]";
	@echo "  <gsize1d*> : Size of one dimension of the grid";
	@echo "             :   0 < gsize1d   , default 32";
	@echo "  <maxnump>  : Maximum number of particles";
	@echo "             : integer > 0     , default 32768";
	@echo "  <nnn1d>    : Number of nearest neighbors along one dimension";
	@echo "             :   0 < nnn1d     , default 4";
	@echo "  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/";
	@echo "  Constraints:  1) gsize1d Should be an integer multiple of nnn1d";
	@echo "             :  2) gsize1d, maxnump, and nnn1d should be a power of 2";
	@echo "             :  3) maxnump >= gsize1d*gsize1d*gsize1d";
	@echo "  /\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\";
	@echo "  <gmrdtype>  : Read delay timing of grid mem blocks";
	@echo "              :   0 <= gmrdtype < 4, default 2";
	@echo "  <pmrdtype>  : Read delay timing of particle mem blocks";
	@echo "              :   0 <= pmrdtype < 4, default 2";
	@echo "";
	@echo "  ///////////////////////";
	@echo "  // wrapped_md_lr_top //";
	@echo "  //////////////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][MAXNUMP=<maxnump>][NNN1D=<nnn1d>][PMRDTYPE=<pmrdtype>][GMRDTYPE=<gmrdtype>]";
	@echo "  <gsize1d*> : Size of one dimension of the grid";
	@echo "             :   0 < gsize1d   , default 32";
	@echo "  <maxnump>  : Maximum number of particles";
	@echo "             : integer > 0     , default 32768";
	@echo "  <nnn1d>    : Number of nearest neighbors along one dimension";
	@echo "             :   0 < nnn1d     , default 4";
	@echo "  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/";
	@echo "  Constraints:  1) gsize1d Should be an integer multiple of nnn1d";
	@echo "             :  2) gsize1d, maxnump, and nnn1d should be a power of 2";
	@echo "             :  3) maxnump >= gsize1d*gsize1d*gsize1d";
	@echo "  /\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\";
	@echo "  <gmrdtype>  : Read delay timing of grid mem blocks";
	@echo "              :   0 <= gmrdtype < 4, default 2";
	@echo "  <pmrdtype>  : Read delay timing of particle mem blocks";
	@echo "              :   0 <= pmrdtype < 4, default 2";
	@echo "";
	@echo "  ////////////////////////";
	@echo "  // fft_idx_translator //";
	@echo "  ////////////////////////";
	@echo "  //";
	@echo "  [NPTS=<npts>][TTYPE=<ttype>]";
	@echo "  <npts> : Number of FFT points";
	@echo "         :   1 < npts, default 32";
	@echo "  <ttype> : Translation ttype:";
	@echo "         :   0 <= ttype, default 0";
	@echo "";
	@echo "  ///////////////////";
	@echo "  // coeffgen_3rdo //";
	@echo "  ///////////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][NNN1D=<nnn1d>][CTYPE=<ctype>][GMRDTYPE=<gmrdtype>]";
	@echo "  <gsize1d*>  : Size of one dimension of the grid";
	@echo "              :   0 < gsize1d   , default 32";
	@echo "  <nnn1d>     : Number of nearest neighbors along one dimension";
	@echo "              :   0 < nnn1d     , default 4";
	@echo "  <ctype>     : Type of generator";
	@echo "              :   0 <= ctype < 4, default 0";
	@echo "  <gmrdtype>  : Read delay timing of grid mem blocks";
	@echo "              :   0 <= gmrdtype < 4, default 2";
	@echo "";
	@echo "  //////////////////////////";
	@echo "  // clustered_greens_rom //";
	@echo "  //////////////////////////";
	@echo "  //";
	@echo "  [GSIZE1DX=<gsize1dx>][GSIZE1DY=<gsize1dy>][GSIZE1DZ=<gsize1dz>][NNN1D=<nnn1d>][GELEW=<gelew>][BRDTYPE=<brdtype>]";
	@echo "  <gsize1d*> : Size of one dimension of the grid";
	@echo "            :   0 < gsize1d   , default 32";
	@echo "  <nnn1d>   : Number of nearest neighbors along one dimension";
	@echo "            :   0 < nnn1d     , default 4";
	@echo "  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/";
	@echo "  Constraint: gsize1d Should be an integer multiple of nnn1d";
	@echo "  /\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\";
	@echo "  <gelew>   : Bit width of each grid element";
	@echo "            :   0 < gelew       , default 64";
	@echo "  <brdtype> : Read delay timing of grid mem blocks";
	@echo "            :   0 <= brdtype < 4, default 0";
	@echo "";
##-----------------------------------------------------------------------------
# Set configuration if not set at command line
BLKS   ?= 1
BDEPTH ?= 1
SEGS   ?= 1
SEGW   ?= 1
RDTYPE ?= 1

GSIZE1D  ?= 32
GSIZE1DX ?= 32
GSIZE1DY ?= 32
GSIZE1DZ ?= 32
NNN1D    ?= 4
GELEW    ?= 64
BRDTYPE  ?= 0

GMRDTYPE ?= 2
PMRDTYPE ?= 2

FPVW     ?= 32
FPADDDEL ?= 5
GRNDEL   ?= 5

MAXNUMP ?= 32768

NPTS ?= 32
TTYPE ?= 0

CTYPE ?= 0

##-----------------------------------------------------------------------------
# Determine name of sandbox. It's the parent of the current working directory
SNDBXLNT = $(shell pwd | rev | cut -d '/' -f 1-2 | rev)

##-----------------------------------------------------------------------------
# Set sandbox directories directory
SNDPATH = $(shell pwd | rev | cut -c 6- | rev)
IPDIR   = ${SNDPATH}/ip
INCDIR  = ${SNDPATH}/include
RTLDIR  = ${SNDPATH}/rtl

##-----------------------------------------------------------------------------
# Set output directory

OUTDIRP = /projects/nobkup/dr949/${USER}/${SNDBXLNT}

OUTDIR  = ${OUTDIRP}/${MOD}

##-----------------------------------------------------------------------------
# Logfile name
ifeq (${MOD},cfg_sp_rw_mem)
  NME = ${MOD}_BLKS${BLKS}_BDEPTH${BDEPTH}_SEGS${SEGS}_SEGW${SEGW}_RDTYPE${RDTYPE}
else ifeq (${MOD},cfg_sp_ro_mem)
  NME = ${MOD}_BLKS${BLKS}_BDEPTH${BDEPTH}_SEGS${SEGS}_SEGW${SEGW}_RDTYPE${RDTYPE}
else ifeq (${MOD},cfg_2p_1r1w_mem)
  NME = ${MOD}_BLKS${BLKS}_BDEPTH${BDEPTH}_SEGS${SEGS}_SEGW${SEGW}_RDTYPE${RDTYPE}
else ifeq (${MOD},clustered_grid_mem)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_NNN1D${NNN1D}_GELEW${GELEW}_BRDTYPE${BRDTYPE}
else ifeq (${MOD},md_lr_top)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_MAXNUMP${MAXNUMP}_NNN1D${NNN1D}_GMRDTYPE${GMRDTYPE}_PMRDTYPE${PMRDTYPE}
else ifeq (${MOD},wrapped_md_lr_top)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_MAXNUMP${MAXNUMP}_NNN1D${NNN1D}_GMRDTYPE${GMRDTYPE}_PMRDTYPE${PMRDTYPE}
else ifeq (${MOD},md_lr_seqr)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_MAXNUMP${MAXNUMP}_NNN1D${NNN1D}_GMRDTYPE${GMRDTYPE}_PMRDTYPE${PMRDTYPE}_FPADDDEL${FPADDDEL}_GRNDEL${GRNDEL}_FPVW${FPVW}
else ifeq (${MOD},fft_idx_translator)
  NME = ${MOD}_NPTS${NPTS}_TTYPE${TTYPE}
else ifeq (${MOD},coeffgen_3rdo)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_NNN1D${NNN1D}_CTYPE${CTYPE}_GMRDTYPE${GMRDTYPE}
else ifeq (${MOD},clustered_greens_rom)
  NME = ${MOD}_GSIZE1DX${GSIZE1DX}_GSIZE1DY${GSIZE1DY}_GSIZE1DZ${GSIZE1DZ}_NNN1D${NNN1D}_GELEW${GELEW}_BRDTYPE${BRDTYPE}
else
  NME = ${MOD}
endif

##-----------------------------------------------------------------------------
# Output Logfiles
CMPLOG = ${OUTDIR}/${NME}.xrun.log
LNTLOG = ${OUTDIR}/${NME}.hal.log
LNTFCT = ${OUTDIR}/${NME}.hal.design_facts

SLOGLOG = ${OUTDIR}/scanlogs.detailed_results

##-----------------------------------------------------------------------------
# Prerequisites:

##########
# Shared #
##########
#
HALDEF = ./scripts/hal.def

${MOD}_CPRE += ${${MOD}_HDL}

#################
# cfg_sp_rw_mem #
#################
#
cfg_sp_rw_mem_HDL  = ${SNDPATH}/rtl/cfg_sp_rw_mem.sv

cfg_sp_rw_mem_LPRE  = ${HALDEF}
cfg_sp_rw_mem_LPRE += ./scripts/design_info_cfg_sp_rw_mem.txt

# Configuration arguments
cfg_sp_rw_mem_CFGARGS += -defparam cfg_sp_rw_mem.BLKS=32\'d${BLKS}
cfg_sp_rw_mem_CFGARGS += -defparam cfg_sp_rw_mem.BDEPTH=32\'d${BDEPTH}
cfg_sp_rw_mem_CFGARGS += -defparam cfg_sp_rw_mem.SEGS=32\'d${SEGS}
cfg_sp_rw_mem_CFGARGS += -defparam cfg_sp_rw_mem.SEGW=32\'d${SEGW}
cfg_sp_rw_mem_CFGARGS += -defparam cfg_sp_rw_mem.RDTYPE=2\'d${RDTYPE}

#################
# cfg_sp_ro_mem #
#################
#
cfg_sp_ro_mem_HDL  = ${SNDPATH}/rtl/cfg_sp_ro_mem.sv

cfg_sp_ro_mem_LPRE  = ${HALDEF}
cfg_sp_ro_mem_LPRE += ./scripts/design_info_cfg_sp_ro_mem.txt

# Configuration arguments
cfg_sp_ro_mem_CFGARGS += -defparam cfg_sp_ro_mem.BLKS=32\'d${BLKS}
cfg_sp_ro_mem_CFGARGS += -defparam cfg_sp_ro_mem.BDEPTH=32\'d${BDEPTH}
cfg_sp_ro_mem_CFGARGS += -defparam cfg_sp_ro_mem.SEGS=32\'d${SEGS}
cfg_sp_ro_mem_CFGARGS += -defparam cfg_sp_ro_mem.SEGW=32\'d${SEGW}
cfg_sp_ro_mem_CFGARGS += -defparam cfg_sp_ro_mem.RDTYPE=2\'d${RDTYPE}

###################
# cfg_2p_1r1w_mem #
###################
#
cfg_2p_1r1w_mem_HDL  = ${SNDPATH}/rtl/cfg_2p_1r1w_mem.sv

cfg_2p_1r1w_mem_LPRE  = ${HALDEF}
cfg_2p_1r1w_mem_LPRE += ./scripts/design_info_cfg_2p_1r1w_mem.txt

# Configuration arguments
cfg_2p_1r1w_mem_CFGARGS += -defparam cfg_2p_1r1w_mem.BLKS=32\'d${BLKS}
cfg_2p_1r1w_mem_CFGARGS += -defparam cfg_2p_1r1w_mem.BDEPTH=32\'d${BDEPTH}
cfg_2p_1r1w_mem_CFGARGS += -defparam cfg_2p_1r1w_mem.SEGS=32\'d${SEGS}
cfg_2p_1r1w_mem_CFGARGS += -defparam cfg_2p_1r1w_mem.SEGW=32\'d${SEGW}
cfg_2p_1r1w_mem_CFGARGS += -defparam cfg_2p_1r1w_mem.RDTYPE=2\'d${RDTYPE}

######################
# clustered_grid_mem #
######################
#
clustered_grid_mem_HDL  = ${cfg_2p_1r1w_mem_HDL}
clustered_grid_mem_HDL += ${SNDPATH}/rtl/clustered_grid_mem.sv

clustered_grid_mem_LPRE  = ${HALDEF}
clustered_grid_mem_LPRE += ./scripts/design_info_clustered_grid_mem.txt

# Configuration arguments
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.GSIZE1DX=32\'d${GSIZE1DX}
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.GSIZE1DY=32\'d${GSIZE1DY}
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.GSIZE1DZ=32\'d${GSIZE1DZ}
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.NNN1D=32\'d${NNN1D}
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.GELEW=32\'d${GELEW}
clustered_grid_mem_CFGARGS += -defparam clustered_grid_mem.BRDTYPE=2\'d${BRDTYPE}

##############
# md_lr_seqr #
##############
#
md_lr_seqr_HDL  = ${SNDPATH}/rtl/md_lr_seqr.sv

md_lr_seqr_INC = -incdir ${SNDPATH}/rtl

md_lr_seqr_CPRE += ${SNDPATH}/rtl/md_lr_pkg.sv

md_lr_seqr_LPRE  = ${HALDEF}
md_lr_seqr_LPRE += ./scripts/design_info_md_lr_seqr.txt

# Configuration arguments
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.GSIZE1DX=32\'d${GSIZE1DX}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.GSIZE1DY=32\'d${GSIZE1DY}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.GSIZE1DZ=32\'d${GSIZE1DZ}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.NNN1D=32\'d${NNN1D}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.MAXNUMP=32\'d${MAXNUMP}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.GMRDTYPE=2\'d${GMRDTYPE}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.FPADDDEL=32\'d${FPADDDEL}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.GRNDEL=32\'d${GRNDEL}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.FPVW=32\'d${FPVW}
md_lr_seqr_CFGARGS += -defparam md_lr_seqr.PMRDTYPE=2\'d${PMRDTYPE}

#############
# md_lr_top #
#############
#
md_lr_top_HDL  = ${cfg_sp_rw_mem_HDL}
md_lr_top_HDL += ${cfg_2p_1r1w_mem_HDL}
md_lr_top_HDL += ${coeffgen_3rdo_HDL}
md_lr_top_HDL += ${md_lr_seqr_HDL}
md_lr_top_HDL += ${clustered_greens_rom_HDL}
md_lr_top_HDL += ${SNDPATH}/rtl/clustered_grid_mem.sv
md_lr_top_HDL += ${SNDPATH}/rtl/md_lr_top.sv
md_lr_top_HDL += ${SNDPATH}/rtl/Reduction_Tree.sv
md_lr_top_HDL += ${SNDPATH}/ip/fftIP/fftIP/fftIP_bb.v
md_lr_top_HDL += ${SNDPATH}/ip/resetRelease/resetRelease/resetRelease_bb.v

md_lr_top_INC = -incdir ${SNDPATH}/rtl

md_lr_top_CPRE += ${SNDPATH}/rtl/md_lr_pkg.sv

md_lr_top_LPRE  = ${HALDEF}
md_lr_top_LPRE += ./scripts/design_info_md_lr_top.txt

# Configuration arguments
md_lr_top_CFGARGS += -defparam md_lr_top.GSIZE1DX=32\'d${GSIZE1DX}
md_lr_top_CFGARGS += -defparam md_lr_top.GSIZE1DY=32\'d${GSIZE1DY}
md_lr_top_CFGARGS += -defparam md_lr_top.GSIZE1DZ=32\'d${GSIZE1DZ}
md_lr_top_CFGARGS += -defparam md_lr_top.MAXNUMP=32\'d${MAXNUMP}
md_lr_top_CFGARGS += -defparam md_lr_top.NNN1D=32\'d${NNN1D}
md_lr_top_CFGARGS += -defparam md_lr_top.GMRDTYPE=2\'d${GMRDTYPE}
md_lr_top_CFGARGS += -defparam md_lr_top.PMRDTYPE=2\'d${PMRDTYPE}

#####################
# wrapped_md_lr_top #
#####################
#
wrapped_md_lr_top_HDL  = ${md_lr_top_HDL}
wrapped_md_lr_top_HDL += ${SNDPATH}/rtl/wrapped_md_lr_top.sv

wrapped_md_lr_top_INC  = -incdir ${SNDPATH}/rtl
wrapped_md_lr_top_INC += -incdir ${SNDPATH}/tb/include

wrapped_md_lr_top_CPRE += ${SNDPATH}/rtl/md_lr_pkg.sv
wrapped_md_lr_top_CPRE += ${SNDPATH}/tb/include/particle_info.svh

wrapped_md_lr_top_LPRE  = ${HALDEF}
wrapped_md_lr_top_LPRE += ./scripts/design_info_wrapped_md_lr_top.txt

# Configuration arguments
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.GSIZE1DX=32\'d${GSIZE1DX}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.GSIZE1DY=32\'d${GSIZE1DY}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.GSIZE1DZ=32\'d${GSIZE1DZ}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.MAXNUMP=32\'d${MAXNUMP}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.NNN1D=32\'d${NNN1D}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.GMRDTYPE=2\'d${GMRDTYPE}
wrapped_md_lr_top_CFGARGS += -defparam wrapped_md_lr_top.PMRDTYPE=2\'d${PMRDTYPE}

######################
# fft_idx_translator #
######################
#
fft_idx_translator_HDL  = ${SNDPATH}/rtl/fft_idx_translator.sv

fft_idx_translator_LPRE  = ${HALDEF}
fft_idx_translator_LPRE += ./scripts/design_info_fft_idx_translator.txt

# Configuration arguments
fft_idx_translator_CFGARGS += -defparam fft_idx_translator.NPTS=32\'d${NPTS}
fft_idx_translator_CFGARGS += -defparam fft_idx_translator.TTYPE=32\'d${TTYPE}

#################
# coeffgen_3rdo #
#################
#
coeffgen_3rdo_HDL  = ${SNDPATH}/rtl/coeffgen_3rdo.sv
coeffgen_3rdo_HDL += ${SNDPATH}/ip/FpAdd/FpAdd/FpAdd_bb.v
coeffgen_3rdo_HDL += ${SNDPATH}/ip/FpMul/FpMul/FpMul_bb.v
coeffgen_3rdo_HDL += ${SNDPATH}/rtl/customdelay.sv
coeffgen_3rdo_HDL += ${SNDPATH}/ip/toFp/toFp/toFp_bb.v

coeffgen_3rdo_LPRE  = ${HALDEF}
coeffgen_3rdo_LPRE += ./scripts/design_info_coeffgen_3rdo.txt

coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.GSIZE1DX=32\'d${GSIZE1DX}
coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.GSIZE1DY=32\'d${GSIZE1DY}
coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.GSIZE1DZ=32\'d${GSIZE1DZ}
coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.NNN1D=32\'d${NNN1D}
coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.CTYPE=32\'d${CTYPE}
coeffgen_3rdo_CFGARGS += -defparam coeffgen_3rdo.GMRDTYPE=2\'d${GMRDTYPE}

########################
# clustered_greens_rom #
########################
#
clustered_greens_rom_HDL  = ${cfg_sp_ro_mem_HDL}
clustered_greens_rom_HDL += ${SNDPATH}/rtl/clustered_greens_rom.sv

clustered_greens_rom_INC = -incdir ${SNDPATH}/rtl

clustered_greens_rom_LPRE  = ${HALDEF}
clustered_greens_rom_LPRE += ./scripts/design_info_clustered_greens_rom.txt

# Configuration arguments
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.GSIZE1DX=32\'d${GSIZE1DX}
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.GSIZE1DY=32\'d${GSIZE1DY}
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.GSIZE1DZ=32\'d${GSIZE1DZ}
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.NNN1D=32\'d${NNN1D}
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.GELEW=32\'d${GELEW}
clustered_greens_rom_CFGARGS += -defparam clustered_greens_rom.BRDTYPE=2\'d${BRDTYPE}


#################
# fft_ring_node #
#################
#
fft_ring_node_HDL  = ${SNDPATH}/rtl/fft_ring_pkg.sv
fft_ring_node_HDL += ${SNDPATH}/rtl/fft_ring_node.sv

fft_ring_node_INC = -incdir ${SNDPATH}/rtl

fft_ring_node_LPRE  = ${HALDEF}
fft_ring_node_LPRE += ./scripts/design_info_fft_ring_node.txt

##-----------------------------------------------------------------------------
# Design Compilation Command
#
CMPCMD  = module load xcelium/19.03.002;
CMPCMD += xrun -sv -64bit -timescale 1ns/100ps
CMPCMD += -nowarn DSEMEL
CMPCMD += -define SYNTHESIS
CMPCMD += -access +C
CMPCMD += -elaborate -snapshot ${MOD}:sv
CMPCMD += -xmlibdirpath ${OUTDIR}
CMPCMD += -l ${CMPLOG}
CMPCMD += -F ${OUTDIR}/${MOD}_hdl.f

ifeq (${${MOD}_VEND},)
  CMPCMD += ;
else
  CMPCMD += -F ${OUTDIR}/${MOD}_vendors.f;
endif

QCMPCMD  = qrsh -q sim.q -o /dev/null -l xcsim=1 -pty y -j y -b y -cwd 
QCMPCMD += -now no -N MDLR_CE "hostname; ${CMPCMD}"

##-----------------------------------------------------------------------------
# Design Lint Command
#
LNTCMD  = module load xcelium/19.03.002; 
LNTCMD += hal -64bit -rulefile ${HALDEF} -lintpragma
LNTCMD += -logfile ${LNTLOG}
LNTCMD += -design_facts_file ${LNTFCT}
LNTCMD += -design_info ./scripts/design_info_${MOD}.txt
LNTCMD += -inst_top ${MOD}
LNTCMD += -cdslib ${OUTDIR}/xcelium.d/${MOD}_sv.d/cds.lib
LNTCMD += worklib.${MOD}:sv;

QLNTCMD  = qrsh -q sim.q -o /dev/null -l xcsim=1 -pty y -j y -b y -cwd 
QLNTCMD += -now no -N MDLR_LNT "hostname; ${LNTCMD}"

##-----------------------------------------------------------------------------
#  Scanlogs Command
#
SLOGCMD = ../tools/scanlogs

##-----------------------------------------------------------------------------
## make target ce_mod: Compile and elaborate module
##-----------------------------------------------------------------------------
ce_mod : ${CMPLOG}

${CMPLOG} : ${${MOD}_CPRE}
# Determine module to be linted to whose lint data needs to be cleaned.
# A valid module has a non-empty set of prerequisite files
ifeq (${${MOD}_CPRE},)
	$(error "${MOD} is an invalid module. Please specify a valid module")
endif
	@mkdir -p ${OUTDIR}
	@echo "" > ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_INC} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" ${${MOD}_HDL} >> ${OUTDIR}/${MOD}_hdl.f
	@echo ${${MOD}_CFGARGS} >> ${OUTDIR}/${MOD}_hdl.f
	@echo "" > ${OUTDIR}/${MOD}_vendors.f
	@echo ${${MOD}_VEND} >> ${OUTDIR}/${MOD}_vendors.f
	${QCMPCMD}

##-----------------------------------------------------------------------------
## make target lint_mod: Lint module that has been compiled and elaborated
##-----------------------------------------------------------------------------
lint_mod : ${LNTLOG}

${LNTLOG} : ${CMPLOG} ${${MOD}_LPRE}
	${QLNTCMD}

##-----------------------------------------------------------------------------
## make target scan_mod_lint: Runs scanlogs on module that has been linted
##-----------------------------------------------------------------------------
scan_mod_lint : ${SLOGLOG}

${SLOGLOG} : ${LNTLOG} ${${MOD}_SPRE}
	@${SLOGCMD} ${CMPLOG} ${LNTLOG}
	@mv scanlogs.detailed_results ${OUTDIR}

##-----------------------------------------------------------------------------
## make target regress_cgm: Runs lint regression over representative set of
##                          clustered_grid_mem configs
##-----------------------------------------------------------------------------
regress_cgm :
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=0 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=0 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=0 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=1 GELEW=64
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=1 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=1 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=2 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=2 GELEW=64
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=2 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=3 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=3 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=3 GELEW=64
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=0 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=0 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=0 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=1 GELEW=64
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=1 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=1 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=2 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=2 GELEW=64
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=2 GELEW=8
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=32 GSIZE1DY=32 GSIZE1DZ=32 NNN1D=4 BRDTYPE=3 GELEW=16
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=64 GSIZE1DY=64 GSIZE1DZ=64 NNN1D=2 BRDTYPE=3 GELEW=32
	make lint_mod MOD=clustered_grid_mem GSIZE1DX=8  GSIZE1DY=8  GSIZE1DZ=8  NNN1D=4 BRDTYPE=3 GELEW=64
	@${SLOGCMD} ${OUTDIRP}/clustered_grid_mem/*.log
	@mv scanlogs.detailed_results ${OUTDIRP}/clustered_grid_mem

##-----------------------------------------------------------------------------
## Clean-Up Targets: 
##-----------------------------------------------------------------------------
clean_mod :
# Determine module to be linted to whose lint data needs to be cleaned.
# A valid module has a non-empty set of prerequisite files
ifeq (${${MOD}_CPRE},)
	$(error "${MOD} is an invalid module. Please specify a valid module")
endif
	rm -rf ${OUTDIR}

clean_all :
	rm -rf ${OUTDIRP}
