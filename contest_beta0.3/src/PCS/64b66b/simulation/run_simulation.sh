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

## Gate-level simulation of the design using Mentor ModelSim.
### Synthesize source verilog files into gate level netlists using DC
### and link produced files (as shown in *.fdo file below) for power estimation.

## Setup Model Sim ##
pushd /usr/groups/ecad
source setup.bash
popd

## Setup Synopsys Tools ##
pushd /usr/groups/ecad/synopsys
source setup.bash
popd


rm -rf work
# Please uncomment this line for behavioral-level simulation
#vsim -gui -do "do {sim_modelsim_behav.fdo}"

# Please uncomment this line for gate-level simulation
vsim -c -do "do {sim_modelsim.fdo}"

# Measure power using Primetime
pt_shell -f $PWD/design_power.scr

