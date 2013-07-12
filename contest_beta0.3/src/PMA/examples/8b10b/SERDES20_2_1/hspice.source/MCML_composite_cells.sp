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

* Models of 8:1:8 and 4:1:4 SerDes-s implemented in MOS Current Mode Logic 
* Basic MCML cells are implemented in 45nm technology process
* =============================================================
* TRANSISTOR MODELS - commercial 45 library

*********************************************************************
*** D-type FF
*********************************************************************
* Subcircuit of a simple MCML Master slave D flip-flop gate
.subckt MCML_DFF_MS dd di cd ci outd outi 
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda
* ==============================================================
* D-la + reamp
X1 dd di cd ci outtd_f outti_f mvdd vrfp_la vrfn_la gnda MCML_DLA
X100 outtd_f outti_f outtd outti mvdd vrfp_inv vrfn_inv gnda MCML_INV
* D-la + reamp
X2 outtd outti ci cd outd_f outi_f mvdd vrfp_la vrfn_la gnda MCML_DLA
X101 outd_f outi_f outd outi mvdd vrfp_inv vrfn_inv gnda MCML_INV

.ends MCML_DFF_MS
*********************************************************************

*** D-type FF with extra latch 
*********************************************************************
* Subcircuit of a simple MCML Master-slave-slave D flip-flop gate
.subckt MCML_DFF_MSS dd di cd ci outd outi 
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda
* ==============================================================
* DFF + D-la
X1 dd di cd ci outtd_f outti_f mvdd vrfp_la vrfn_la  gnda MCML_DLA
X100 outtd_f outti_f outtd outti mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X2 outtd outti ci cd out2td_f out2ti_f mvdd vrfp_la vrfn_la  gnda MCML_DLA
X101 out2td_f out2ti_f out2td out2ti mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X3 out2td out2ti cd ci outd_f outi_f mvdd vrfp_la vrfn_la  gnda MCML_DLA
X102 outd_f outi_f outd outi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

.ends MCML_DFF_MSS
*********************************************************************

***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************

*** 2:1 SERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_SERIAL21 i[1] i[2] clk_tx clk_enbl outd outi
+ c2x_cmos
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv mvdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_tx cd_txc ci_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_1 cd_txc ci_txc cd_tx ci_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_txc cei_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_3 ced_txc cei_txc ced_tx cei_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** Input signals conversion and reshaping
X000 i[1] i1d i1i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X101 i1d i1i i1dd i1ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X001 i[2] i2d i2i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X102 i2d i2i i2dd i2ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_tx cei_tx cd_tx ci_tx cdd_txa cdi_txa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_txa cdi_txa cdi_tx cdd_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input distributed to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in different clk domains
X005_0 cdd_tx cdi_tx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***

*** clk -- cd & ci
X200_1 cdd_tx cdi_tx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Convert clk/2 back to feed CMOS SER ***
X500_4 c2xd c2xi c2x_cmos mvdd_cmos vrfn_conv mvdd_cmos gnda MCML_to_CMOS
******************** End of generation of different clock domains ********************

******************** Tree-based 2-to-1 Multiplexer ********************
**************** Stage 1 *****************
*** shift signals i1 && i2 differently ***
X10_1 i1d i1i c2xd c2xi st1_q1db_post st1_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X10_3 st1_q1db_post st1_q1ib_post st1_q1d_post st1_q1i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X10_2 i2d i2i c2xd c2xi st1_q2db_post st1_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X10_4 st1_q2db_post st1_q2ib_post st1_q2d_post st1_q2i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV

***  multiplex signals though SEL2:1 
X10_5 st1_q2d_post st1_q2i_post st1_q1d_post st1_q1i_post c2xd c2xi st0_q1db st0_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X10_6 st0_q1db st0_q1ib st0_q1d st0_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV


**************** Stage 0 *****************
*** final retiming with D-FF and equalization
X11 st0_q1d st0_q1i cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la outd outi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

******************** End of TREE based 2 to 1 Multiplexer ********************

.ends MCML_SERIAL21
*********************************************************************

*** 1:2 DESERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_DESERIAL12 ind ini clk_rx clk_enbl
+ c2x_cmos
+ o[1] o[2] 
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv vdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_rx cd_rxc ci_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_1 cd_rxc ci_rxc cd_rx ci_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_rxc cei_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_3 ced_rxc cei_rxc ced_rx cei_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_rx cei_rx cd_rx ci_rx cdd_rxa cdi_rxa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_rxa cdi_rxa cdi_rx cdd_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input distribution to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in different clk domains
X005_0 cdd_rx cdi_rx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***

*** clk -- cd & ci
X200_1 cdd_rx cdi_rx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Conversion clk/2 to CMOS level to feed CMOS DES *******************
X500_4 c2xd c2xi c2x_cmos vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
******************** End of generation of different clock domains ********************

****************** Tree-based 1:2 Demultiplexer *********************
****************** Stage 0 *********************
*** retiming, reshaping and demuxing
X8 ind ini cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la ind_des ini_des mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 1 *********************
*** demuxing 1 differential signal into 2 signals 
X9_1 ind_des ini_des c2xd c2xi st1_q1db st1_q1ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X9_2 st1_q1db st1_q1ib st1_q1d st1_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X9_3 ind_des ini_des c2xi c2xd st1_q2db st1_q2ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X9_4 st1_q2db st1_q2ib st1_q2d st1_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** final equalization 
X110 st1_q1d st1_q1i q1d_b q1i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X111 st1_q2d st1_q2i q2d_b q2i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** conversion to CMOS level
X120 q2d_b q2i_b o[1] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X121 q1d_b q1i_b o[2] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS

.ends MCML_DESERIAL12
*********************************************************************


***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************

*** 4:1 SERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_SERIAL41 i[1] i[2] i[3] i[4] clk_tx clk_enbl outd outi 
+ c4x_cmos
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv mvdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_tx cd_txc ci_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_1 cd_txc ci_txc cd_tx ci_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_txc cei_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_3 ced_txc cei_txc ced_tx cei_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** Input signals conversion and reshaping 
X000 i[1] i1d i1i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X101 i1d i1i i1dd i1ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X001 i[2] i2d i2i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X102 i2d i2i i2dd i2ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X002 i[3] i3d i3i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X103 i3d i3i i3dd i3ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X003 i[4] i4d i4i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X104 i4d i4i i4dd i4ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_tx cei_tx cd_tx ci_tx cdd_txa cdi_txa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_txa cdi_txa cdi_tx cdd_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in different clk domains
X005_0 cdd_tx cdi_tx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_1 c_outd c_outi c2d c2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Second static frequency divider - f/4 ***
X2 c_out2i c_out2d c2i c2d c_out2d c_out2i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***

*** clk -- cd & ci
X200_1 cdd_tx cdi_tx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/4 -- c4d & c4i
X400_1 c_out2d c_out2i c4xd c4xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*X400_1 c_out2d c_out2i c4d_o c4i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*X400_2 c4d_o c4i_o c4xd c4xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV


**** convert back to CMOS level to feed CMOS SER ***
X500_4 c4xd c4xi c4x_cmos mvdd_cmos vrfn_conv mvdd_cmos gnda MCML_to_CMOS
******************** End of generation of different clock domains ********************

******************** Tree-based 4-to-1 multiplexer ********************
**************** Stage 2 *****************
*** Mux1 - Shift & select for i1,i2 pair ***
X4_1 i1dd i1ii c4xd c4xi st2_q1db_post st2_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X4_3 st2_q1db_post st2_q1ib_post st2_q1d st2_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_2 i2dd i2ii c4xd c4xi st2_q2db_post st2_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X4_4 st2_q2db_post st2_q2ib_post st2_q2d st2_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_5 st2_q2d st2_q2i st2_q1d st2_q1i c4xd c4xi st1_q1db st1_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X4_6 st1_q1db st1_q1ib st1_q1d st1_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Mux2 - Shift & select for i3,i4 pair ***
X5_1 i3dd i3ii c4xd c4xi st2_q3db_post st2_q3ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X5_3 st2_q3db_post st2_q3ib_post st2_q3d st2_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_2 i4dd i4ii c4xd c4xi st2_q4db_post st2_q4ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X5_4 st2_q4db_post st2_q4ib_post st2_q4d st2_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_5 st2_q4d st2_q4i st2_q3d st2_q3i c4xd c4xi st1_q2db st1_q2ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X5_6 st1_q2db st1_q2ib st1_q2d st1_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

**************** Stage 1 *****************
*** Mux1 - Shift & select i12 & i34 pair ***
X10_1 st1_q1d st1_q1i c2xd c2xi st1_q1db_post st1_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X10_3 st1_q1db_post st1_q1ib_post st1_q1d_post st1_q1i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_2 st1_q2d st1_q2i c2xd c2xi st1_q2db_post st1_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X10_4 st1_q2db_post st1_q2ib_post st1_q2d_post st1_q2i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_5 st1_q2d_post st1_q2i_post st1_q1d_post st1_q1i_post c2xd c2xi st0_q1db st0_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X10_6 st0_q1db st0_q1ib st0_q1d st0_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

**************** Stage 0 *****************
*** final retiming and equalization
X11 st0_q1d st0_q1i cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la outd outi mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of 4-to-1 multiplexer ********************

.ends MCML_SERIAL41
*********************************************************************

*** 1:4 DESERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_DESERIAL14 ind ini clk_rx clk_enbl
+ c4x_cmos
+ o[1] o[2] o[3] o[4]
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv vdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_rx cd_rxc ci_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_1 cd_rxc ci_rxc cd_rx ci_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_rxc cei_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_3 ced_rxc cei_rxc ced_rx cei_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_rx cei_rx cd_rx ci_rx cdd_rxa cdi_rxa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_rxa cdi_rxa cdi_rx cdd_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in different clk domains
X005_0 cdd_rx cdi_rx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_1 c_outd c_outi c2d c2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Second static frequency divider - f/4 ***
X2 c_out2i c_out2d c2i c2d c_out2d c_out2i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***

*** clk -- cd & ci
X200_1 cdd_rx cdi_rx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/4 -- c4d & c4i
X400_1 c_out2d c_out2i c4xd c4xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Bring back to CMOS level to feed CMOS DES ***
X500_4 c4xd c4xi c4x_cmos vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
*********** End of generation of different clock domains ****************

******************** tree-based 1-to-4 demultiplexer ********************
****************** Stage 0 *********************
*** retiming and equalization 
X8 ind ini cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la ind_des ini_des mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 1 *********************
*** extract and reshape first 2 signals
*** 
X9_1 ind_des ini_des c2xd c2xi st1_q2db st1_q2ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X9_2 st1_q2db st1_q2ib st1_q2d st1_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X9_3 ind_des ini_des c2xi c2xd st1_q1db st1_q1ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X9_4 st1_q1db st1_q1ib st1_q1d st1_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 2 *********************
*** further extract 2 original signals -- pair 1
X10_1 st1_q2d st1_q2i c4xd c4xi st2_q3db st2_q3ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X10_2 st2_q3db st2_q3ib st2_q3d st2_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_3 st1_q2d st1_q2i c4xi c4xd st2_q4db st2_q4ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X10_4 st2_q4db st2_q4ib st2_q4d st2_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** further extract 2 original signals -- pair 2
X11_1 st1_q1d st1_q1i c4xd c4xi st2_q1db st2_q1ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X11_2 st2_q1db st2_q1ib st2_q1d st2_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X11_3 st1_q1d st1_q1i c4xi c4xd st2_q2db st2_q2ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X11_4 st2_q2db st2_q2ib st2_q2d st2_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** equalization and conversion back to CMOS level
X110 st2_q1d st2_q1i q1d_b q1i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X111 st2_q2d st2_q2i q2d_b q2i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X112 st2_q3d st2_q3i q3d_b q3i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X113 st2_q4d st2_q4i q4d_b q4i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X120 q1d_b q1i_b o[1] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X121 q2d_b q2i_b o[2] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X122 q3d_b q3i_b o[3] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X123 q4d_b q4i_b o[4] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS

.ends MCML_DESERIAL14
*********************************************************************


*****************************************************************************************
*****************************************************************************************
*****************************************************************************************
*****************************************************************************************
*****************************************************************************************
*****************************************************************************************

*** 8:1 SERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_SERIAL81 i[1] i[2] i[3] i[4] i[5] i[6] i[7] i[8] clk_tx clk_enbl outd outi
+ c8x_cmos
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv mvdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_tx cd_txc ci_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_1 cd_txc ci_txc cd_tx ci_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_txc cei_txc mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X004_3 ced_txc cei_txc ced_tx cei_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** Input signals conversion and reshaping 
X000 i[1] i1d i1i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X101 i1d i1i i1dd i1ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X001 i[2] i2d i2i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X102 i2d i2i i2dd i2ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X002 i[3] i3d i3i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X103 i3d i3i i3dd i3ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X003 i[4] i4d i4i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X104 i4d i4i i4dd i4ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X004 i[5] i5d i5i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X105 i5d i5i i5dd i5ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X005 i[6] i6d i6i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X106 i6d i6i i6dd i6ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X006 i[7] i7d i7i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X107 i7d i7i i7dd i7ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV

X007 i[8] i8d i8i mvdd vrfp_conv vrfn_conv mvdd_cmos  gnda CMOS_to_MCML
X108 i8d i8i i8dd i8ii mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_tx cei_tx cd_tx ci_tx cdd_txa cdi_txa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_txa cdi_txa cdi_tx cdd_tx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input distro to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in diff. clk domains
X005_0 cdd_tx cdi_tx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_1 c_outd c_outi c2d c2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Second static frequency divider - f/4 ***
X2 c_out2i c_out2d c2i c2d c_out2d c_out2i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_2 c_out2d c_out2i c4d c4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Third static frequency divider - f/8 ***
X3 c_out4i c_out4d c4i c4d c_out4d c_out4i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***
*** clk -- cd & ci
X200_1 cdd_tx cdi_tx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd_5b c2xi_5b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_7 c2xd_5b c2xi_5b c2xd_6b c2xi_6b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_8 c2xd_6b c2xi_6b c2xd_7b c2xi_7b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_9 c2xd_7b c2xi_7b c2xd_8b c2xi_8b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_10 c2xd_8b c2xi_8b c2xd_9b c2xi_9b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_11 c2xd_9b c2xi_9b c2xd_10b c2xi_10b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_12 c2xd_10b c2xi_10b c2xd_11b c2xi_11b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_13 c2xd_11b c2xi_11b c2xd_12b c2xi_12b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_14 c2xd_12b c2xi_12b c2xd_13b c2xi_13b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_15 c2xd_13b c2xi_13b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV


*** clk/4 -- c4d & c4i
X400_1 c_out2d c_out2i c4d_o c4i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_2 c4d_o c4i_o c4xd_b c4xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_3 c4xd_b c4xi_b c4xd_2b c4xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_4 c4xd_2b c4xi_2b c4xd_3b c4xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_5 c4xd_3b c4xi_3b c4xd_4b c4xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_6 c4xd_4b c4xi_4b c4xd_5b c4xi_5b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_7 c4xd_5b c4xi_5b c4xd_6b c4xi_6b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_8 c4xd_6b c4xi_6b c4xd_7b c4xi_7b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_9 c4xd_7b c4xi_7b c4xd c4xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/8 -- c8d & c8i
X500_1 c_out4d c_out4i c8d_o c8i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X500_2 c8d_o c8i_o c8xd_b c8xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X500_3 c8xd_b c8xi_b c8xd c8xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of generation of different clock domains ********************

*** Bring back to CMOS level to feed CMOS SER ***
X500_4 c8xd c8xi c8x_cmos mvdd_cmos vrfn_conv mvdd_cmos gnda MCML_to_CMOS

******************** tree-based 8-to-1 multiplexer ********************
**************** Stage 3 *****************
*** Mux 3_1 ------ i1 + i2 - shifting & reshaping 
X4_7 i1dd i1ii c8xd c8xi st3_q1db_post st3_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X4_8 st3_q1db_post st3_q1ib_post st3_q1d_post st3_q1i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_9 i2dd i2ii c8xd c8xi st3_q2db_post st3_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X4_10 st3_q2db_post st3_q2ib_post st3_q2d_post st3_q2i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_11 st3_q2d_post st3_q2i_post st3_q1d_post st3_q1i_post c8xd c8xi st3_q1db st3_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X4_12 st3_q1db st3_q1ib st3_q1d st3_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Mux 3_2 ------ i3 + i4 - shifting & reshaping
X5_7 i3dd i3ii c8xd c8xi st3_q3db_post st3_q3ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X5_8 st3_q3db_post st3_q3ib_post st3_q3d_post st3_q3i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_9 i4dd i4ii c8xd c8xi st3_q4db_post st3_q4ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X5_10 st3_q4db_post st3_q4ib_post st3_q4d_post st3_q4i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_11 st3_q4d_post st3_q4i_post st3_q3d_post st3_q3i_post c8xd c8xi st3_q2db st3_q2ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X5_12 st3_q2db st3_q2ib st3_q2d st3_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Mux 3_3 ------ i5 + i6 - shifting & reshaping
X6_7 i5dd i5ii c8xd c8xi st3_q5db_post st3_q5ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X6_8 st3_q5db_post st3_q5ib_post st3_q5d_post st3_q5i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X6_9 i6dd i6ii c8xd c8xi st3_q6db_post st3_q6ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X6_10 st3_q6db_post st3_q6ib_post st3_q6d_post st3_q6i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X6_11 st3_q6d_post st3_q6i_post st3_q5d_post st3_q5i_post c8xd c8xi st3_q3db st3_q3ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X6_12 st3_q3db st3_q3ib st3_q3d st3_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Mux 3_4 ------ i7 + i8 - shifting & reshaping
X7_7 i7dd i7ii c8xd c8xi st3_q7db_post st3_q7ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X7_8 st3_q7db_post st3_q7ib_post st3_q7d_post st3_q7i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X7_9 i8dd i8ii c8xd c8xi st3_q8db_p*** 2:1 SERIALIZER BLOCK ***ost st3_q8ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X7_10 st3_q8db_post st3_q8ib_post st3_q8d_post st3_q8i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X7_11 st3_q8d_post st3_q8i_post st3_q7d_post st3_q7i_post c8xd c8xi st3_q4db st3_q4ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X7_12 st3_q4db st3_q4ib st3_q4d st3_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV


**************** Stage 2 *****************
*** Mux 2_1 ------ i12 + i34 - shifting & reshaping
X4_1 st3_q1d st3_q1i c4xd c4xi st2_q1db_post st2_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X4_3 st2_q1db_post st2_q1ib_post st2_q1d st2_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_2 st3_q2d st3_q2i c4xd c4xi st2_q2db_post st2_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X4_4 st2_q2db_post st2_q2ib_post st2_q2d st2_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X4_5 st2_q2d st2_q2i st2_q1d st2_q1i c4xd c4xi st1_q1db st1_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X4_6 st1_q1db st1_q1ib st1_q1d st1_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Mux 2_2 ------ i56 + i78 - shifting & reshaping
X5_1 st3_q3d st3_q3i c4xd c4xi st2_q3db_post st2_q3ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X5_3 st2_q3db_post st2_q3ib_post st2_q3d st2_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_2 st3_q4d st3_q4i c4xd c4xi st2_q4db_post st2_q4ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X5_4 st2_q4db_post st2_q4ib_post st2_q4d st2_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X5_5 st2_q4d st2_q4i st2_q3d st2_q3i c4xd c4xi st1_q2db st1_q2ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X5_6 st1_q2db st1_q2ib st1_q2d st1_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV


**************** Stage 1 *****************
*** Mux 1_1 ------ i1234 + i5678 - shifting & reshaping
X10_1 st1_q1d st1_q1i c2xd c2xi st1_q1db_post st1_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X10_3 st1_q1db_post st1_q1ib_post st1_q1d_post st1_q1i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_2 st1_q2d st1_q2i c2xd c2xi st1_q2db_post st1_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X10_4 st1_q2db_post st1_q2ib_post st1_q2d_post st1_q2i_post mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_5 st1_q2d_post st1_q2i_post st1_q1d_post st1_q1i_post c2xd c2xi st0_q1db st0_q1ib mvdd vrfp_la vrfn_la gnda MCML_SEL21
X10_6 st0_q1db st0_q1ib st0_q1d st0_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

**************** Stage 0 *****************
*** final retiming and equalization
X11 st0_q1d st0_q1i cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la outd outi mvdd vrfp_inv vrfn_inv  gnda MCML_INV
************* End of 8-to-1 multiplexer ********************

.ends MCML_SERIAL81
*********************************************************************


*** 1:8 DESERIALIZER BLOCK ***
*********************************************************************
.subckt MCML_DESERIAL18 ind ini clk_rx clk_enbl
+ c8x_cmos
+ o[1] o[2] o[3] o[4] o[5] o[6] o[7] o[8]
+ mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv vrfp_conv vrfn_conv vdd_cmos  gnda

******************** CMOS to MCML signal conversion ********************
*** Input clock conversion ***
X004_0 clk_rx cd_rxc ci_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_1 cd_rxc ci_rxc cd_rx ci_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Enable signal conversion ***
X004_2 clk_enbl ced_rxc cei_rxc mvdd vrfp_conv vrfn_conv vdd_cmos  gnda CMOS_to_MCML
X004_3 ced_rxc cei_rxc ced_rx cei_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of CMOS to MCML signal conversion ********************

******************** Generation of different clock domains ********************
*** Main clock (with enable) ***
X004_5 ced_rx cei_rx cd_rx ci_rx cdd_rxa cdi_rxa mvdd vrfp_la vrfn_la gnda MCML_AND
X004_6 cdd_rxa cdi_rxa cdi_rx cdd_rx mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Clk input to the cascade of frequency dividers ***
*** Change polarity to get edge alignment in diff. clk domains
X005_0 cdd_rx cdi_rx cd ci mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** First static frequency divider - f/2 ***
X1 c_outi c_outd ci cd c_outd c_outi mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_1 c_outd c_outi c2d c2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Second static frequency divider - f/4 ***
X2 c_out2i c_out2d c2i c2d c_out2d c_out2i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X005_2 c_out2d c_out2i c4d c4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** Third static frequency divider - f/8 ***
X3 c_out4i c_out4d c4i c4d c_out4d c_out4i mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS

********* Alignment of clock edges -- delay lines **********
*** IMPORTANT: clk distr. nw should be adjusted to meet timing ***

*** clk -- cd & ci
X200_1 cdd_rx cdi_rx cxd cxi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/2 -- c2d & c2i
X300_1 c_outd c_outi c2d_o c2i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_2 c2d_o c2i_o c2xd_b c2xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_3 c2xd_b c2xi_b c2xd_2b c2xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_4 c2xd_2b c2xi_2b c2xd_3b c2xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_5 c2xd_3b c2xi_3b c2xd_4b c2xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_6 c2xd_4b c2xi_4b c2xd_5b c2xi_5b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_7 c2xd_5b c2xi_5b c2xd_6b c2xi_6b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_8 c2xd_6b c2xi_6b c2xd_7b c2xi_7b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_9 c2xd_7b c2xi_7b c2xd_8b c2xi_8b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_10 c2xd_8b c2xi_8b c2xd_9b c2xi_9b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_11 c2xd_9b c2xi_9b c2xd_10b c2xi_10b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_12 c2xd_10b c2xi_10b c2xd_11b c2xi_11b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_13 c2xd_11b c2xi_11b c2xd_12b c2xi_12b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_14 c2xd_12b c2xi_12b c2xd_13b c2xi_13b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X300_15 c2xd_13b c2xi_13b c2xd c2xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/4 -- c4d & c4i
X400_1 c_out2d c_out2i c4d_o c4i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_2 c4d_o c4i_o c4xd_b c4xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_3 c4xd_b c4xi_b c4xd_2b c4xi_2b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_4 c4xd_2b c4xi_2b c4xd_3b c4xi_3b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_5 c4xd_3b c4xi_3b c4xd_4b c4xi_4b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_6 c4xd_4b c4xi_4b c4xd_5b c4xi_5b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_7 c4xd_5b c4xi_5b c4xd_6b c4xi_6b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_8 c4xd_6b c4xi_6b c4xd_7b c4xi_7b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X400_9 c4xd_7b c4xi_7b c4xd c4xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** clk/8 -- c8d & c8i
X500_1 c_out4d c_out4i c8d_o c8i_o mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X500_2 c8d_o c8i_o c8xd_b c8xi_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X500_3 c8xd_b c8xi_b c8xd c8xi mvdd vrfp_inv vrfn_inv  gnda MCML_INV
******************** End of generation of different clock domains ********************

*** Bring back to CMOS level to feed CMOS DES ***
X500_4 c8xd c8xi c8x_cmos vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS

****************** Stage 0 *********************
*** retiming and equalization 
X8 ind ini cxd cxi outd_la outi_la mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X600_1 outd_la outi_la ind_des ini_des mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 1 *********************
*** DEMUX1_1  --- separate 8765 + 4321 & reshape
X9_1 ind_des ini_des c2xd c2xi st1_q2db st1_q2ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X9_2 st1_q2db st1_q2ib st1_q2d st1_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
****
X9_3 ind_des ini_des c2xi c2xd st1_q1db st1_q1ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X9_4 st1_q1db st1_q1ib st1_q1d st1_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 2 *********************
*** DEMUX2_1  --- separate 87 + 65 & reshape
X10_1 st1_q2d st1_q2i c4xd c4xi st2_q3db st2_q3ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X10_2 st2_q3db st2_q3ib st2_q3d st2_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X10_3 st1_q2d st1_q2i c4xi c4xd st2_q4db st2_q4ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X10_4 st2_q4db st2_q4ib st2_q4d st2_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** DEMUX2_2  --- separate 43 + 21 & reshape
X11_1 st1_q1d st1_q1i c4xd c4xi st2_q1db st2_q1ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X11_2 st2_q1db st2_q1ib st2_q1d st2_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
****
X11_3 st1_q1d st1_q1i c4xi c4xd st2_q2db st2_q2ib mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X11_4 st2_q2db st2_q2ib st2_q2d st2_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

****************** Stage 3 *********************
*** DEMUX3_1  --- separate 8 + 7 & reshape
X12_1 st2_q3d st2_q3i c8xd c8xi st3_q1db_post st3_q1ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X12_2 st3_q1db_post st3_q1ib_post st3_q1d st3_q1i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X12_3 st2_q3d st2_q3i c8xi c8xd st3_q2db_post st3_q2ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X12_4 st3_q2db_post st3_q2ib_post st3_q2d st3_q2i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** DEMUX3_2  --- separate 6 + 5 & reshape
X13_1 st2_q4d st2_q4i c8xd c8xi st3_q3db_post st3_q3ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X13_2 st3_q3db_post st3_q3ib_post st3_q3d st3_q3i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X13_3 st2_q4d st2_q4i c8xi c8xd st3_q4db_post st3_q4ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X13_4 st3_q4db_post st3_q4ib_post st3_q4d st3_q4i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** DEMUX3_3  --- separate 4 + 3 & reshape
X14_1 st2_q1d st2_q1i c8xd c8xi st3_q5db_post st3_q5ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X14_2 st3_q5db_post st3_q5ib_post st3_q5d st3_q5i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X14_3 st2_q1d st2_q1i c8xi c8xd st3_q6db_post st3_q6ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X14_4 st3_q6db_post st3_q6ib_post st3_q6d st3_q6i mvdd vrfp_inv vrfn_inv  gnda MCML_INV

*** DEMUX3_4  --- separate 2 + 1 & reshape
X15_1 st2_q2d st2_q2i c8xd c8xi st3_q7db_post st3_q7ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MS
X15_2 st3_q7db_post st3_q7ib_post st3_q7d st3_q7i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X15_3 st2_q2d st2_q2i c8xi c8xd st3_q8db_post st3_q8ib_post mvdd vrfp_la vrfn_la vrfp_inv vrfn_inv gnda MCML_DFF_MSS
X15_4 st3_q8db_post st3_q8ib_post st3_q8d st3_q8i mvdd vrfp_inv vrfn_inv  gnda MCML_INV
 
*** final equalization  & conversion to CMOS level *************
X110 st3_q1d st3_q1i q1d_b q1i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X111 st3_q2d st3_q2i q2d_b q2i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X112 st3_q3d st3_q3i q3d_b q3i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X113 st3_q4d st3_q4i q4d_b q4i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X114 st3_q5d st3_q5i q5d_b q5i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X115 st3_q6d st3_q6i q6d_b q6i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X116 st3_q7d st3_q7i q7d_b q7i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
X117 st3_q8d st3_q8i q8d_b q8i_b mvdd vrfp_inv vrfn_inv  gnda MCML_INV
*** 
X120 q6d_b q6i_b o[1] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X121 q5d_b q5i_b o[2] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X122 q8d_b q8i_b o[3] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X123 q7d_b q7i_b o[4] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X124 q2d_b q2i_b o[5] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X125 q1d_b q1i_b o[6] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X126 q4d_b q4i_b o[7] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS
X127 q3d_b q3i_b o[8] vdd_cmos vrfn_conv vdd_cmos gnda MCML_to_CMOS

.ends MCML_DESERIAL18
*********************************************************************
