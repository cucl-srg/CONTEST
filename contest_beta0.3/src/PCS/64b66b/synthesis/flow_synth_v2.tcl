# Written by Andrew West, May 2008
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

# #
# #    Synthesis in Design Compiler Topographical	
# #

# Minor update for clockgating, Dec 2012


if ![shell_is_in_topographical_mode] then {echo "Must run synth in topographical mode e.g. design_vision -topo";exit}

set_host_options -max_cores 2
report_host_options

# ###########
# ###########  RUN CONTROL
# ###########

set ultratiming [get_unix_variable ARG_TIMING]
set quit_after_compile [get_unix_variable ARG_QUITAFTERCOMPILE]
set my_top_level [get_unix_variable ARG_TOPLEVEL]
set my_source_files [get_unix_variable ARG_SOURCES]
set my_blocks [get_unix_variable ARG_BLOCKS]

set my_num_blocks 0
foreach b $my_blocks {
   set my_num_blocks [expr $my_num_blocks+1]
}


# ###########
# ###########  DESIGN KIT AND CONSTRAINTS
# ###########

source ../flow_defines.tcl

set target_library $my_target_library
for {set ind 0} {$ind < [llength $my_max_libraries_list]} {incr ind} {
   set maxlib [lindex $my_max_libraries_list $ind]
   set minlib [lindex $my_min_libraries_list $ind]
   echo "set_min_library $maxlib -min_version $minlib"
   set_min_library $maxlib -min_version $minlib
}

# ###########
# ###########  DC OPTIONS
# ###########

set sh_script_stop_severity E
set sh_continue_on_error false

set compile_log_format "  %elap_time %area(.0) %wns(.3) %tns %drc %endpoint"
set default_schematic_options "-size infinite"
set write_name_nets_same_as_ports "true"
set verilogout_no_tri "true"
set fsm_auto_inferring true
set hdlin_report_fsm true
set compile_automatic_clock_phase_inference strict
set hdlin_ff_always_sync_set_reset true
set hdlin_infer_complex_set_reset true
set sh_enable_page_mode false
set enable_page_mode false

# do not show Verilog 2001 synth may not match older simulation tool
suppress_message VER-311
# do not show "defining new variable"
suppress_message CMD-041
# do not show "Design rule attributes from the driving cell will be set on the port"
suppress_message UID-401
# do not show "Changed minimum wire load model for '...' from 'zero_load' to 'suggested_10K'."
suppress_message OPT-171
# old hdl compiler warning about signing
suppress_message VER-314


# ###########
# ###########  ERROR MESSAGES
# ###########

set myerrv "----- ERROR: VERILOG PARSING FAILED  -----"
set myerrc "----- ERROR: TOP-LEVEL MODULE NOT FOUND  -----"
set myerrl "----- ERROR: LINK FAILED, MISSING MODULE? -----"
set myerrsdc "------ WARNING: NO SDC FILE! USING DEFAULT TIMING OPTIONS ------"

# ###########
# ###########  OPEN MILKYWAY
# ###########

if {[file exists $my_mw_library]} {
   open_mw_lib $my_mw_library
} else {
   create_mw_lib -technology $my_tech_file -mw_reference_library $my_ref_library -open $my_mw_library
}
### Check only loaded (logical) libcells
check_library -cells [get_attribute [get_lib_cells */*] name]

# ###########
# ###########  LOAD TLUplus
# ###########

set_tlu_plus_files -max_tluplus $my_tlu_plus_file -min_tluplus $my_tlu_plus_file -tech2itf_map $my_tf_to_itf_map_file
check_tlu_plus_files

# ###########
# ###########  READ VERILOG SOURCES
# ###########

set_vsdc $my_netlist_path/$my_top_level.vsdc

set search_path [concat $search_path $my_source_path]

set success [analyze -format verilog -library WORK $my_source_files]
if { $success == "" } {echo "";echo $myerrv;echo "";quit}

elaborate $my_top_level
current_design $my_top_level
set success [set_critical_range $my_critical_range $my_top_level]
if { $success == 0 } {echo "";echo $myerrc;echo "";quit}


# ###########
# ###########  APPLY CONSTRAINTS
# ###########

set_fsm_encoding_style auto
set_fsm_minimize true
set fsm_enable_state_minimization true
set fsm_set_safe_mode true

for {set ind 0} {$ind < [llength $my_max_libraries_list]} {incr ind} {
   set maxlib [lindex $my_max_libraries_list $ind]
   set minlib [lindex $my_min_libraries_list $ind]
   set maxlibname [lindex $my_max_libname_list $ind]
   set minlibname [lindex $my_min_libname_list $ind]
   set maxopcond [lindex $my_max_opcond_list $ind]
   set minopcond [lindex $my_min_opcond_list $ind]
   set_operating_conditions -max $maxopcond -max_library $maxlib:$maxlibname -min $minopcond -min_library $minlib:$minlibname
   report_operating_conditions -library $maxlib:$maxlibname
   report_operating_conditions -library $minlib:$minlibname
}

set success [set_critical_range $my_critical_range $my_top_level]
if { $success == 0 } {echo "";echo $myerrc;echo "";quit}

set_max_transition $my_max_transition $my_top_level
set_max_transition $my_max_transition_outputs [all_outputs]
set_input_transition -max $my_input_transition [all_inputs]
set_driving_cell -lib_cell $my_input_drive_cell_equivalent [all_inputs]

set_load -pin_load $my_output_load_capacitance [all_outputs]
set_max_fanout $my_max_fanout $my_top_level
set_fix_multiple_port_nets -all -buffer_constants

#### Opt
set_max_area 0
set_max_dynamic_power 0
###set_power_prediction true

### May choose to not use very weak cells (library dependent)
#set_dont_use [get_lib_cells {*/*LP */*P}]

set true_delay_prove_false_backtrack_limit 10000000
set true_delay_prove_true_backtrack_limit  10000000

set derive_default_routing_layer_direction false
set_utilization [expr $my_target_utilisation_pc / 100.0]
set_preferred_routing_direction -layers $my_horizontal_layers -direction H
set_preferred_routing_direction -layers $my_vertical_layers -direction V

# ###########
# ###########  CLOCK GATING
# ###########

# Set that we would like DFT control port
set_clock_gating_style -control_point before -control_signal scan_enable

# Set latch-based clock gating
set_clock_gating_style -positive_edge_logic integrated

# Do not add clock gates in their own level of hierarchy (needed for SPICE writer)
set_app_var power_cg_flatten true


# ###########
# ###########  TIMING CONSTRAINTS
# ###########

if {[file exists $my_source_path/$my_top_level.sdc]} {
   source -echo -verbose $my_source_path/$my_top_level.sdc
} else {
   echo "";echo $myerrsdc;echo "";echo $myerrsdc;echo "";
   read_sdc -echo $my_source_path/default.sdc
}

# ###########
# ###########  TOPOGRAPHICAL SYNTHESIS
# ###########

set success [link]
if { $success == 0 } {echo "";echo $myerrl;echo "";quit}

check_design
redirect $my_netlist_path/$my_top_level.check_design {check_design}

if {$my_enable_expensive_flattening} {
   set_flatten true -design $my_top_level -effort high -minimize single_output -phase true
   set_structure true -design $my_top_level -boolean true -timing true
}

set_fix_multiple_port_nets -all -buffer_constants

## Fix hold as we need hold to be clean for simulation to be reliable
foreach_in_collection c [get_clocks -quiet *] {
   set_fix_hold $c
}

## Sequential inversion makes subsequent formal verification / debug more difficult, for very limited gains
## Strongly recommend not enabling it
if {$ultratiming} {
     compile_ultra -timing_high_effort_script -gate_clock -no_seq_output_inversion
     compile_ultra -only_design_rule -incremental	
} else {
   compile_ultra -gate_clock -no_seq_output_inversion
}

### Must be flat for SPICE netlisting at the moment
ungroup -all -flatten 
compile_ultra -incremental -no_seq_output_inversion



# ###########
# ###########  WRITE OUTPUT FILES
# ###########


exec echo $my_blocks >$my_netlist_path/$my_top_level.blocks

set_vsdc -off
change_names -rules verilog -hierarchy

write -format verilog -hierarchy -output $my_netlist_path/$my_top_level.v
write -format ddc -hierarchy -compress gzip -output $my_netlist_path/$my_top_level.ddc

## Create HSPICE netlist and instantiation
source ../flow_write_spice.tcl

###write_sdf -version 1.0 $my_netlist_path/$my_top_level.sdf
###write_sdc -version latest $my_netlist_path/$my_top_level.sdc
###write_script -full_path_lib_names -output $my_netlist_path/$my_top_level.scr

if {$my_true_path_check} {
   redirect $my_netlist_path/$my_top_level.max {report_timing -path full -true -transition_time -capacitance -delay max -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group}
   redirect $my_netlist_path/$my_top_level.min {report_timing -path full -justify -transition_time -capacitance -delay min -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group}
} else {
   redirect $my_netlist_path/$my_top_level.max {report_timing -path full -transition_time -capacitance -delay max -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group}
   redirect $my_netlist_path/$my_top_level.min {report_timing -path full -transition_time -capacitance -delay min -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group}
}


# ###########
# ###########  REPORT CELL USE
# ###########

report_reference -nosplit


# ###########
# ###########  REPORT AREA
# ###########

report_area -nosplit


# ###########
# ###########  REPORT AUTO UNGROUPING
# ###########

report_auto_ungroup -nosplit


# ###########
# ###########  REPORT CLOCK NETS
# ###########

if {[sizeof_collection [all_clocks]]>0} {
   report_net  [all_clocks]
}

# ###########
# ###########  REPORT CONSTRAINT VIOLATIONS
# ###########

report_constraint -nosplit -all_vio -significant_digits 3
redirect $my_netlist_path/$my_top_level.vio {report_constraint -nosplit -all_vio -significant_digits 3}

# ###########
# ###########  REPORT DISABLED TIMING ARCS
# ###########

report_disable_timing -nosplit

# ###########
# ###########  REPORT STATUS
# ###########

report_constraint -max_delay -min_delay -nosplit -significant_digits 3

# ###########
# ###########  REPORT INFERENCE (e.g. DesignWare)
# ###########

report_resources

# ###########
# ###########  REPORT QOR
# ###########

report_qor -nosplit -significant_digits 3
redirect $my_netlist_path/$my_top_level.qor {report_qor -nosplit -significant_digits 3}

# ###########
# ###########  TIMING RESULTS (MIN)
# ###########

if {$my_true_path_check} {
   report_timing -path full -transition_time -capacitance -delay min -justify -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group
} else {
   report_timing -path full -transition_time -capacitance -delay min -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group
}

# ###########
# ###########  TIMING RESULTS (MAX)
# ###########

if {$my_true_path_check} {
   report_timing -path full -true -transition_time -capacitance -delay max -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group
} else {
   report_timing -path full -transition_time -capacitance -delay max -nworst 1 -max_paths 1 -significant_digits 3 -sort_by group
}


if $quit_after_compile then quit
gui_start
gui_create_schematic
gui_show_window -show_state maximized -window Schematic.1
gui_zoom -window Schematic.1 -full
gui_write_window_image -window [gui_get_current_window -view -mru] -file $my_netlist_path/$my_top_level.png


# End of synthesis script


