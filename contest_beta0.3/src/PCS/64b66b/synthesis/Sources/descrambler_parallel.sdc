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

### Clocks: Synthesise to meet 156.25 MHz (with margin)
create_clock -period 6.2 clock

### Optimise in propagated (non-ideal) clock mode so hold timing can be fixed in DC (add some margin)
set_propagated_clock clock
set_clock_uncertainty -setup 0.0 clock
set_clock_uncertainty -hold  0.014 clock
set_auto_disable_drc_nets -clock false

### Crude constraint from clock to output 
set_max_delay -to [get_ports -filter port_direction==out *] 0.45

### Crude constraint from input to flop
set_max_delay -from [get_ports -filter port_direction==in *] 0.15

##set_dont_touch reset

## Don't select scan flip flops (usually worse for timing)
set_dont_touch [get_lib_cells */SDFF*]
set_dont_use [get_lib_cells */SDFF*]


