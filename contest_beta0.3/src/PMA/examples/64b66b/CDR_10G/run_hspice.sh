#!/bin/bash

# Written by Andrew West
#
# Comments, suggestions for improvement and criticism welcome
# E-mail:  Andrew.West~at~cl.cam.ac.uk
#
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

# Reference HSPICE accuracy

#### BEGIN LOCAL SETUP
pushd /usr/groups/ecad/synopsys
source setup.bash
popd
#### END LOCAL SETUP

rm -f test.mt* test.pa* test.st* test.tr* test.ic* test.inc
mkdir -p tempdir.stimulus
pushd tempdir.stimulus
perl ../flow_dsi_v0p7.pl ../test.dsi test
popd

echo -e "** HSPICE standard accuracy\n" >>test.inc
echo ".include 'test.spi'" >>test.inc
echo ".end" >>test.inc

## Use 6 cores by default to speed up simulation
hspice -d -mt 6 -i test.inc | tee -i hspice.out


