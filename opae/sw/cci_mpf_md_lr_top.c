//
// Copyright (c) 2017, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <uuid/uuid.h>

#include <opae/fpga.h>

// State from the AFU's JSON file, extracted using OPAE's afu_json_mgr script
#include "afu_json_info.h"

#define CACHELINE_BYTES 64
#define CL(x) ((x) * CACHELINE_BYTES)

#define LINES 34429 // Number of lines in the input sequence.


//
// Search for an accelerator matching the requested UUID and connect to it.
//
static fpga_handle connect_to_accel(const char *accel_uuid)
{
    fpga_properties filter = NULL;
    fpga_guid guid;
    fpga_token accel_token;
    uint32_t num_matches;
    fpga_handle accel_handle;
    fpga_result r;

    // Don't print verbose messages in ASE by default
    setenv("ASE_LOG", "0", 0);

    // Set up a filter that will search for an accelerator
    fpgaGetProperties(NULL, &filter);
    fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);

    // Add the desired UUID to the filter
    uuid_parse(accel_uuid, guid);
    fpgaPropertiesSetGUID(filter, guid);

    // Do the search across the available FPGA contexts
    num_matches = 1;
    fpgaEnumerate(&filter, 1, &accel_token, 1, &num_matches);

    // Not needed anymore
    fpgaDestroyProperties(&filter);

    if (num_matches < 1)
    {
        fprintf(stderr, "Accelerator %s not found!\n", accel_uuid);
        return 0;
    }

    // Open accelerator
    r = fpgaOpen(accel_token, &accel_handle, 0);
    assert(FPGA_OK == r);

    // Done with token
    fpgaDestroyToken(&accel_token);

    return accel_handle;
}


//
// Allocate a buffer in I/O memory, shared with the FPGA.
//
static volatile void* alloc_buffer(fpga_handle accel_handle,
                                   ssize_t size,
                                   uint64_t *wsid,
                                   uint64_t *io_addr)
{
    fpga_result r;
    volatile void* buf;

    r = fpgaPrepareBuffer(accel_handle, size, (void*)&buf, wsid, 0);
    if (FPGA_OK != r) return NULL;

    // Get the physical address of the buffer in the accelerator
    r = fpgaGetIOAddress(accel_handle, *wsid, io_addr);
    assert(FPGA_OK == r);

    return buf;
}

void print_err(const char *s, fpga_result res)
{
    fprintf(stderr, "Error %s: %s\n", s, fpgaErrStr(res));
}

void mmio_write_64(fpga_handle afc_handle, uint64_t addr, uint64_t data, const char *reg_name)
{
    fpga_result res = fpgaWriteMMIO64(afc_handle, 0, addr, data);
    if (res != FPGA_OK)
    {
        print_err("mmio_write_64 failure", res);
        exit(1);
    }
    printf("MMIO Write to %s (Byte Offset=%08lx) = %08lx\n", reg_name, addr, data);
}

void mmio_read_64(fpga_handle afc_handle, uint64_t addr, uint64_t *data, const char *reg_name)
{
    fpga_result res = fpgaReadMMIO64(afc_handle, 0, addr, data);
    if (res != FPGA_OK)
    {
        print_err("mmio_read_64 failure", res);
        exit(1);
    }

    printf("Reading %s (Byte Offset=%08lx) = %08lx\n", reg_name, addr, *data);
}

int main(int argc, char *argv[])
{
    fpga_handle accel_handle;

    uint64_t           rdata=0;
    uint64_t           fvalid=0;
    uint64_t           flast=0;

    uint32_t           force=0;

    int ii;

    float exp_fx, exp_fy, exp_fz;
    float rec_fx, rec_fy, rec_fz;


    // Include particle info constants
    #include "particle_info.h"
    //#include "force_info.h"
    #include "rtl_force_info.h"

    // Find and connect to the accelerator
    accel_handle = connect_to_accel(AFU_ACCEL_UUID);
    mmio_read_64(accel_handle, 0x40*4, &rdata, "pready");

    for (ii=0; ii<LINES; ii=ii+1) {
      // Write Particle Data Values
      mmio_write_64(accel_handle, 0x42*4, p_info[ii][11], "pwdata[0+:16]");
      mmio_write_64(accel_handle, 0x44*4, p_info[ii][10], "pwdata[16+:16]");
      mmio_write_64(accel_handle, 0x46*4, p_info[ii][ 9], "pwdata[32+:16]");
      mmio_write_64(accel_handle, 0x48*4, p_info[ii][ 8], "{5'd0, pwdata[48+:11]}");
      mmio_write_64(accel_handle, 0x4A*4, p_info[ii][ 7], "pwdata[59+:4]");
      mmio_write_64(accel_handle, 0x4C*4, p_info[ii][ 6], "pwdata[63+:16]");
      mmio_write_64(accel_handle, 0x4E*4, p_info[ii][ 5], "{5'd0, pwdata[79+:11]}");
      mmio_write_64(accel_handle, 0x50*4, p_info[ii][ 4], "pwdata[90+:4]");
      mmio_write_64(accel_handle, 0x52*4, p_info[ii][ 3], "pwdata[94+:16]");
      mmio_write_64(accel_handle, 0x54*4, p_info[ii][ 2], "{5'd0, pwdata[110+:11]}");
      mmio_write_64(accel_handle, 0x56*4, p_info[ii][ 1], "pwdata[121+:4]");
 
      if (ii==LINES-1) {
	// Set 'last' indicator bit
	mmio_write_64(accel_handle, 0x58*4, 0x0001, "plast");
      }

      // Toggle Valid line
      mmio_write_64(accel_handle, 0x5E*4, p_info[ii][0], "pvalid");
    }

    // Check that pready is de-asserted maning that DUT is performing calculation
    mmio_read_64(accel_handle, 0x40*4, &rdata, "pready");

    while (fvalid==0) {
      mmio_read_64(accel_handle, 0x60*4, &fvalid, "fvalid");
    }

    ii = 0;   

    while (flast==0) {
      // Read force information
      // X
      mmio_read_64(accel_handle, 0x64*4, &rdata, "fdata[16+:16]");

      force = 0x0000FFFF & rdata;
      force = force << 16;

      mmio_read_64(accel_handle, 0x62*4, &rdata, "fdata[0+:16]");

      force = force | (0x0000FFFF & rdata);

      exp_fx = *((float*)&p_force[ii][0]);
      printf("Expected fx = %f\n", exp_fx);

      rec_fx = *((float*)&force);
      printf("Received fx = %f\n", rec_fx);

      if (exp_fx == rec_fx) {
        printf("Force X check of particle %0d PASSED\n", ii);
      } else {
        printf("Force X check of particle %0d FAILED\n", ii);
        printf("Expected: %x  Received: %x\n", p_force[ii][0], force);
        printf("Expected: %f  Received: %f\n", exp_fx, rec_fx);

        if (p_force[ii][0] != 0) {
          printf("Percent error %f\n", (rec_fx - exp_fx)*100/exp_fx);
        }
      }

      // Y
      mmio_read_64(accel_handle, 0x68*4, &rdata, "fdata[48+:16]");

      force = 0x0000FFFF & rdata;
      force = force << 16;

      mmio_read_64(accel_handle, 0x66*4, &rdata, "fdata[32+:16]");

      force = force | (0x0000FFFF & rdata);

      exp_fy = *((float*)&p_force[ii][1]);
      printf("Expected fy = %f\n", exp_fy);

      rec_fy = *((float*)&force);
      printf("Received fy = %f\n", rec_fy);

      if (exp_fy == rec_fy) {
        printf("Force Y check of particle %0d PASSED\n", ii);
      } else {
        printf("Force Y check of particle %0d FAILED\n", ii);
        printf("Expected: %x  Received: %x\n", p_force[ii][1], force);
        printf("Expected: %f  Received: %f\n", exp_fy, rec_fy);

        if (p_force[ii][1] != 0) {
          printf("Percent error %f\n", (rec_fy - exp_fy)*100/exp_fy);
        }
      }

      // Z
      mmio_read_64(accel_handle, 0x6C*4, &rdata, "fdata[80+:16]");

      force = 0x0000FFFF & rdata;
      force = force << 16;

      mmio_read_64(accel_handle, 0x6A*4, &rdata, "fdata[64+:16]");
 
      force = force | (0x0000FFFF & rdata);

      exp_fz = *((float*)&p_force[ii][2]);
      printf("Expected fz = %f\n", exp_fz);

      rec_fz = *((float*)&force);
      printf("Received fz = %f\n", rec_fz);

      if (exp_fz == rec_fz) {
        printf("Force Z check of particle %0d PASSED\n", ii);
      } else {
        printf("Force Z check of particle %0d FAILED\n", ii);
        printf("Expected: %x  Received: %x\n", p_force[ii][2], force);
        printf("Expected: %f  Received: %f\n", exp_fz, rec_fz);

        if (p_force[ii][2] != 0) {
          printf("Percent error %f\n", (rec_fz - exp_fz)*100/exp_fz);
        }
      }

      mmio_read_64(accel_handle, 0x6E*4, &flast, "flast");
 
      // Toggle ready line to get new data */
      mmio_write_64(accel_handle, 0x7E*4, 0x0001, "fready");

      ii=ii+1;
    }

    mmio_read_64(accel_handle, 0x40*4, &rdata, "pready");

    // Done
    fpgaClose(accel_handle);

    return 0;
}
