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

ssh -K -X cattin "\
   cd $PWD; \
   pushd /usr/groups/ecad/synopsys; \
   source setup.bash; \
   popd; \
   /usr/groups/ecad/synopsys/CosmosScope-A-2007.12/ai_bin/cscope -pfiles test.tr0; \
"
