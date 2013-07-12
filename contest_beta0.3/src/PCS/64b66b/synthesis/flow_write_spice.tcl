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

#
#  Write a SPICE netlist of structural netlist
#
#  From flow defines: requires $my_vss, $my_vdd, $my_library_spice, $my_top_level, $my_netlist_path
#

### Determine the port order
unset -nocomplain port_order
set subckt_lines [exec grep -i \.subckt $my_library_spice | tr -s \ ] ; 1
foreach line [split $subckt_lines "\n"] {
   set items [split [regsub { +$} $line ""] " "]
   set port_order([lindex $items 1]) [lrange $items 2 end]
}
if {[info exists debug] && $debug} {
   parray port_order
}

### Determine net parasitic information

redirect -variable junk {
   extract_rc -estimate
   set subckt [get_object_name [current_design]]
}

redirect -var tmp {report_units}
regexp {Resistance_unit +: (.*) Ohm\(} $tmp -> runit
regexp {Capacitive_load_unit +: (.*) Farad\(} $tmp -> cunit

set pg_power ${my_vdd}_$my_top_level
set pg_ground ${my_vss}_$my_top_level
set ips [string map [list \{ {} \} {}] [lsort [get_attribute [remove_from_collection [all_inputs] [all_outputs]] full_name]]]
set ops [string map [list \{ {} \} {}] [lsort [get_attribute [all_outputs] full_name]]]

### Write netlist and parasitics

redirect $my_netlist_path/$my_top_level.spi {
   puts "*** SPICE structural netlist of '$subckt' after Design Compiler synthesis, based on port order in '$my_library_spice' ***\n"
   puts ".SUBCKT $subckt $pg_power $pg_ground $ips $ops  "
   unset -nocomplain net_cap
   unset -nocomplain net_res
   puts "*** instances"
   set unused_ctr 0
   foreach_in_collection c [get_cells *] {
      puts -nonewline "x[get_attribute $c name]  "
      foreach p $port_order([get_attribute $c ref_name]) {
         if {$p == $my_vdd} {
            puts -nonewline "$pg_power "
            continue
         }
         if {$p == $my_vss} {
            puts -nonewline "$pg_ground "
            continue
         }
         set pin [get_pins [get_object_name $c]/$p]
         set n [get_attribute [get_nets -of $pin] name]
         if {$n==""} {
            set n "SPICE_NETLIST_UNCONNECTED_[incr unused_ctr]"
            puts -nonewline "${n} "
         } else {
            if {![info exists net_cap($n)]} {
               ##puts "\nNET '$n'  PORT '$p'   CELL '[get_object_name $c]'"
               set net_cap($n) [expr $cunit*[get_attribute [get_nets $n] load]]
               set net_res($n) [expr $runit*[get_attribute [get_nets $n] ba_net_resistance]]
            }
            if {[get_attribute $pin direction]=="in"} {
               puts -nonewline "${n}___rc "
            } else {
               puts -nonewline "${n} "
            }
         }
      }
      puts " [get_attribute $c ref_name]"
   }
   puts "*** Estimated net resistances from Design Compiler"
   set ctr 0
   foreach n [lsort [array names net_res]] {
      puts "r[incr ctr] ${n} ${n}___rc $net_res($n)"
   }
   puts "*** Estimated net capacitances from Design Compiler"
   set ctr 0
   foreach n [lsort [array names net_cap]] {
      puts "c[incr ctr] ${n}___rc $pg_ground $net_cap($n)"
   }
   puts ".ENDS\n*** End\n"
}
puts "Written '$my_netlist_path/$my_top_level.spi'"

redirect $my_netlist_path/$my_top_level.instantiation.spi {
   puts "*** Instance of '$my_top_level'\n"
   puts "XDUT\n+ $pg_power $pg_ground\n+ $ips \n+ $ops \n+ $my_top_level\n\n*** End\n"
}

puts "Written '$my_netlist_path/$my_top_level.instantiation.spi'"
