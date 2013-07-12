#!/bin/bash

#
# Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
# Copyright and related rights are licensed under the Hardware License, 
# Version 2.0 (the "License"); you may not use this file except in 
# compliance with the License. You may obtain a copy of the License at
# http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
# Unless required by applicable law or agreed to in writing, software, 
# hardware and materials distributed under this License is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#
#

### Compile source verilog file into a gate level netlist using DC

## Setup Synopsys Tools ##
pushd /usr/groups/ecad/synopsys
source setup.bash
popd

rm -rf csrc simv;
vcs +v2k -timescale=1ps/1ps +notimingcheck "./Sources/behavior/tb_pcs.v" \
  "../synthesis/out.synth/small_async_fifo.v" \
  "../synthesis/out.synth/encoder_64B66B.v" \
  "../synthesis/out.synth/scrambler_parallel.v" \
  "../synthesis/out.synth/descrambler_parallel.v" \
  "../synthesis/out.synth/decoder_64B66B.v" \
  "./Sources/behavior/commercial-hacked.v"  && ./simv

#dve -help
#dve  

