***  Written by Yury Audzevich
*** 
***  Comments, suggestions for improvement and criticism welcome
***  E-mail:  yury.audzevich~at~cl.cam.ac.uk
*** 
*** 
***  Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
***  Copyright and related rights are licensed under the Hardware License, 
***  Version 2.0 (the "License"); you may not use this file except in 
***  compliance with the License. You may obtain a copy of the License at
***  http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
***  Unless required by applicable law or agreed to in writing, software, 
***  hardware and materials distributed under this License is distributed 
***  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
***  either express or implied. See the License for the specific language
***  governing permissions and limitations under the License.
*** 
*** 


*** MOS CML cell library ***

**********************************
*** ====== MCML cells ======== ***
**********************************

*********************************************************************
* Subcircuit of a simple MOS CML Inverter/Buffer + CS Power gating
.subckt MCML_INV dd di outd outi mvdd vrfp vrfn gnda
* ==============================================================

M1 outi vrfp mvdd mvdd PMOS_VTL W=SLL_P_WIDTH L=SLL_P_LENGTH 
M2 outd vrfp mvdd mvdd PMOS_VTL W=SLL_P_WIDTH L=SLL_P_LENGTH 
M3 outi dd ic gnda NMOS_VTL W=SLL_N_WIDTH L=SLL_N_LENGTH 
M4 outd di ic gnda NMOS_VTL W=SLL_N_WIDTH L=SLL_N_LENGTH 
M5 ic vrfn gnda gnda NMOS_VTL W=SLL_NSOURCE_WIDTH L=SLL_NSOURCE_LENGTH 

.ends MCML_INV
*********************************************************************

*********************************************************************
* Subcircuit of a simple MOS CML D-Latch gate && CS power gating
.subckt MCML_DLA dd di cd ci outd outi mvdd vrfp vrfn gnda
* ==============================================================

M1 outi vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH 
M2 outd vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH 
M3 outi dd ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M4 outd di ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M5 outi outd bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M6 outd outi bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M7 ac cd cc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M8 bc ci cc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M9 cc vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH

.ends MCML_DLA
*********************************************************************

*********************************************************************
* Subcircuit of a simple MOS CML OR/NOR gate
.subckt MCML_OR ad ai bd bi outd outi mvdd vrfp vrfn gnda
* ==============================================================

* the gate 
M1 outd vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH
M2 outi vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH  
M3 outd bi bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH  
M4 outi bd bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH 
M5 bc ai ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M6 outi mvdd vddc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH 
M7 vddc ad ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M8 ac vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH

.ends MCML_OR
*********************************************************************

*******************************************************************
* Subcircuit of a simple MOS CML AND/NAND gate
* similar to OR/NOR with different labeling
.subckt MCML_AND ad ai bd bi outd outi mvdd vrfp vrfn gnda
* ==============================================================
* the gate
M1 outi vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH  
M2 outd vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH  
M3 outi bd bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M4 outd bi bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH   
M5 bc ad ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH 
M6 outd mvdd vddc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH  
M7 vddc ai ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M8 ac vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH

.ends MCML_AND
*********************************************************************

*********************************************************************
* Subcircuit of a simple MOS CML XOR/NXOR gate
.subckt MCML_XOR ad ai bd bi outd outi mvdd vrfp vrfn gnda
* ==============================================================
* the gate
M1 outd vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH  
M2 outi vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH  
M3 outd ad acl gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M4 outi ai acl gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M5 outd ai acr gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M6 outi ad acr gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M7 acl bd bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M8 acr bi bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M9 bc vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH

.ends MCML_XOR
*********************************************************************

*********************************************************************
* Subcircuit of a simple MOS CML MUX2_1 gate
.subckt MCML_SEL21 ad ai bd bi cd ci outd outi mvdd vrfp vrfn gnda
* ==============================================================
* the gate 
M1 outi vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH
M2 outd vrfp mvdd mvdd PMOS_VTL W=DLL_P_WIDTH L=DLL_P_LENGTH
M3 outi ad ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M4 outd ai ac gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M5 outi bd bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M6 outd bi bc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M7 ac ci cc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M8 bc cd cc gnda NMOS_VTL W=DLL_N_WIDTH L=DLL_N_LENGTH
M9 cc vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH

.ends MCML_SEL21
*********************************************************************


****************************************
*** ====== MCML<>CMOS conv. ======== ***
****************************************

*********************************************************************
* CMOS to MCML conversion circuit 
.subckt CMOS_to_MCML in outd outi mvdd vrfp vrfn cvdd gnda 
* ==============================================================

* CMOS part - INV_X1
M2 ini in cvdd cvdd PMOS_VTL W=CONV_CMOS_P_WIDTH L=0.05U
M1 ini in gnda gnda NMOS_VTL W=CONV_CMOS_N_WIDTH L=0.05U
*
M4 ind ini cvdd cvdd PMOS_VTL W=CONV_CMOS_P_WIDTH L=0.05U  
M3 ind ini gnda gnda NMOS_VTL W=CONV_CMOS_N_WIDTH L=0.05U
* MCML gate
M9 outi vrfp mvdd mvdd PMOS_VTL W=CONV_P_WIDTH L=CONV_P_LENGTH
M10 outd vrfp mvdd mvdd PMOS_VTL W=CONV_P_WIDTH L=CONV_P_LENGTH 
M11 outi ind ic gnda NMOS_VTL W=CONV_N_WIDTH L=CONV_N_LENGTH
M12 outd ini ic gnda NMOS_VTL W=CONV_N_WIDTH L=CONV_N_LENGTH 
M13 ic vrfn gnda gnda NMOS_VTL W=CONV_NSOURCE_WIDTH L=CONV_NSOURCE_LENGTH 

.ends CMOS_to_MCML
********************************************************************* 

*********************************************************************
* MCML to CMOS conversion
.subckt MCML_to_CMOS ind ini out mvdd vrfn cvdd gnda
* ==============================================================
* MCML gate
M1 mvdd pc pc mvdd PMOS_VTL W=CONV_P_WIDTH L=CONV_P_LENGTH
M2 mvdd nc nc mvdd PMOS_VTL W=CONV_P_WIDTH L=CONV_P_LENGTH
M3 ic ini pc gnda NMOS_VTL W=CONV_N_WIDTH L=CONV_N_LENGTH
M4 ic ind nc gnda NMOS_VTL W=CONV_N_WIDTH L=CONV_N_LENGTH 
M5 gnda vrfn ic gnda NMOS_VTL W=CONV_NSOURCE_WIDTH L=CONV_NSOURCE_LENGTH

* CMOS part 
M6 gnda bc bc gnda NMOS_VTL W=CONV_CMOS_N_WIDTH L=0.05U
M7 cvdd nc bc cvdd PMOS_VTL W=CONV_CMOS_P_WIDTH L=0.05U
*
M8 gnda bc ppa gnda NMOS_VTL W=CONV_CMOS_N_WIDTH L=0.05U
M9 cvdd pc ppa cvdd PMOS_VTL W=CONV_CMOS_P_WIDTH L=0.05U
*
M10 gnda ppa out gnda NMOS_VTL W=CONV_CMOS_N_WIDTH L=0.05U
M11 cvdd ppa out cvdd PMOS_VTL W=CONV_CMOS_P_WIDTH L=0.05U

.ends MCML_to_CMOS
*********************************************************************

*********************************************************************
*** add simple biasing circuits + simple current mirror ***
*********************************************************************



