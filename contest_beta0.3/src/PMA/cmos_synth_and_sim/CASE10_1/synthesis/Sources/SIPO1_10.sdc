# Written by Yury Audzevich
#
# Comments, suggestions for improvement and criticism welcome
# E-mail:  yury.audzevich~at~cl.cam.ac.uk
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
###

### Constraint unit is nanoseconds

### Clocks: Synthesise to meet 6.25GHz with 10% margin = 150ps
create_clock -period 0.160 CLK_IN

### Fix hold timing (add delay to avoid register failure)
##set_propagated_clock CLK_IN
##set_clock_uncertainty -setup 0.01 CLK_IN
##set_clock_uncertainty -hold  0.02 CLK_IN
##set_auto_disable_drc_nets -clock false

### Crude constraint from clock to output
##set_max_delay -to [get_ports -filter port_direction==out *] 0.07

### Crude constraint from input to flop
##set_max_delay -from [get_ports -filter port_direction==in *] 0.045

set_clock_uncertainty 0.02 CLK_IN

set_dont_touch_network CLK_IN
set_dont_touch_network RESET_IN

