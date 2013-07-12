;# Written by Andrew West, Jan 2012
;#
;# Comments, suggestions for improvement and criticism welcome
;# E-mail:  Andrew.West~at~cl.cam.ac.uk
;#
;#
;# Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
;# Copyright and related rights are licensed under the Hardware License, 
;# Version 2.0 (the "License"); you may not use this file except in 
;# compliance with the License. You may obtain a copy of the License at
;# http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
;# Unless required by applicable law or agreed to in writing, software, 
;# hardware and materials distributed under this License is distributed 
;# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
;# either express or implied. See the License for the specific language
;# governing permissions and limitations under the License.
;#
;#

;# flow_defines.tcl
;#
;# Setup for a Nangate45 prototyping synthesis using /usr/groups/ecad/kits/commercial45_v2010_12/
;#
;# Time values in ns, capacitance in pF, widths in um


set my_kit   /usr/groups/ecad/kits/commercial45_v2010_12


### If synthesis takes too long, disable this option
set my_enable_expensive_flattening  1


;#######################################
;####   Global Design Constraints   ####
;#######################################

set my_critical_range               1.0
set my_max_transition               0.4
set my_max_transition_outputs       0.2
set my_max_fanout                   40

set my_output_load_capacitance      0.010
set my_input_drive_cell_equivalent  INV_X1
set my_input_transition             0.4

set hdlin_while_loop_iterations     5000

;###########################
;####   Floorplanning   ####
;###########################

set my_target_utilisation_pc         75
set my_horizontal_layers             {metal1 metal3 metal5 metal7 metal9}
set my_vertical_layers               {metal2 metal4 metal6 metal8 metal10}

;########################################
;####   Technology : Power Supplies  ####
;########################################

set my_vdd               VDD
set my_vss               VSS
set my_vdd_rail_min      0.95
set my_vdd_rail_typ      1.10
set my_vdd_rail_max      1.25


;####################################
;####   Paths: Synthesis Views   ####
;####################################

set my_library_spice                  "$my_kit/n45-library-netlist-withparasitics.spi"
set my_max_libraries_list             [list "$my_kit/n45-library-timing-TT_1V10_25.ccsdb"]
set my_max_libname_list               [list NangateOpenCellLibrary]
set my_max_opcond_list                [list typical]
set my_min_libraries_list             [list "$my_kit/n45-library-timing-FF_1V25_N40.ccsdb"]
set my_min_libname_list               [list NangateOpenCellLibrary]
set my_min_opcond_list                [list low_temp]
set my_target_library                 $my_max_libraries_list
set synthetic_library                 "dw_foundation.sldb"
set link_library                      [list "*" [join $my_max_libraries_list { }] [join $my_min_libraries_list { }] $synthetic_library]


;###################################
;####   Paths: Physical Views   ####
;###################################

set my_kit_gds             $my_kit/n45-library-layout.gds
set my_tech_file           $my_kit/n45-library.milkywaytech
set my_lef_header_file     $my_kit/n45-library-tech.lef
set my_ref_library         $my_kit/n45-library-MilkywayDB
set my_tlu_plus_file       $my_kit/n45-process-temp25.tluplus
set my_tlu_plus_map_file   $my_kit/n45-mapping.tf2itf
set my_tf_to_itf_map_file  $my_kit/n45-mapping.tf2itf


;################################
;####   Paths: View Naming   ####
;################################

set my_placed_cell       _PLC___$my_top_level
set my_cts_cell          _CTS___$my_top_level
set my_routed_cell       _RTD___$my_top_level
set my_integrity_cell    _XTK___$my_top_level


;##########################
;####   Paths: Flow    ####
;##########################

set my_source_path       ../Sources
set my_netlist_path      ../out.synth
set my_placed_path       ../out.place
set my_routed_path       ../out.route
set my_export_path       ../out.export
set my_mw_library_path   ..
set my_mw_library_name   MilkywayDB
set my_mw_library        $my_mw_library_path/$my_mw_library_name


;###########################
;####   Miscellaneous   ####
;###########################

set my_verify_success   " <<<<<<  VERIFICATION SUCCESSFUL  >>>>>>> "
set my_verify_fail      " XXX XXX XXX    VERIFICATION FAILED    XXX XXX XXX "
set my_filler_string    "xofiller"
set my_num_cpus         2
set my_true_path_check  false

;#########################
;####   END OF FILE   ####
;#########################
