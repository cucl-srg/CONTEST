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

rm -rf out.synth
rm -rf tempdir.synth/*.mr
rm -rf tempdir.synth/*.v
rm -rf tempdir.synth/*.pvl
rm -rf tempdir.synth/*.syn
rm -rf tempdir.synth/*.svf
rm -rf MilkywayDB

bash run_synthesis_DC2012.sh  small_async_fifo batch  | tee log.small_async_fifo
bash run_synthesis_DC2012.sh  tx_dual_8b10b_fast batch  | tee log.tx_dual_8b10b_fast
bash run_synthesis_DC2012.sh  rx_dual_8b10b_fast batch  | tee log.rx_dual_8b10b_fast
bash run_synthesis_DC2012.sh  comma_detect batch  | tee log.comma_detect



