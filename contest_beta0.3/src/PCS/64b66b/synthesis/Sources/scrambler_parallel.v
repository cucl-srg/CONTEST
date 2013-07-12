`timescale 1ns / 1ps

//  Written by Yury Audzevich
// 
//  Comments, suggestions for improvement and criticism welcome
//  E-mail:  yury.audzevich~at~cl.cam.ac.uk
// 
// 
//  Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
//  Copyright and related rights are licensed under the Hardware License, 
//  Version 2.0 (the "License"); you may not use this file except in 
//  compliance with the License. You may obtain a copy of the License at
//  http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
//  Unless required by applicable law or agreed to in writing, software, 
//  hardware and materials distributed under this License is distributed 
//  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language
//  governing permissions and limitations under the License.
// 
// 
//////////////////////////////////////////////////////////////////////////////////
// Description : Parallel scrambler shuffles 64-bit words according to a specific 
// polinomial (2-bit synch. header is left intact, POLY is shown below), within 
// one clock cycle. 
// The module comes without training procedure implemented.
//////////////////////////////////////////////////////////////////////////////////
module scrambler_parallel(data_in, dataout, scram_enable, bypass_enable, reset, clock);
 
 input wire [65:0] data_in;				// sync header + data from encoder
 input wire reset;					// reset logic
 input wire clock;					// clock
 input wire scram_enable;			// enable scrambler, if disabled - send previous state
 input wire bypass_enable;			// bypass scrambler, if enabled - send unscrambled data
 
 output reg [65:0] dataout;				// synch header + scrambled data
 
////////////////////////////////////////////////////////////////
 wire [63:0] scramb_outs;			// scrambled data
 
 reg [57:0] in_regs;					// intermediate scrambler registers, set to 1's initially
 reg [63:0] datain;
 reg [1:0]  sync_header;			// synchronization header
 
 //====================================================
 // scrambling outs - polinomials are presented below
assign scramb_outs[0] = in_regs[57]^in_regs[38]^datain[0];
assign scramb_outs[1] = in_regs[56]^in_regs[37]^datain[1];
assign scramb_outs[2] = in_regs[55]^in_regs[36]^datain[2];
assign scramb_outs[3] = in_regs[54]^in_regs[35]^datain[3];
assign scramb_outs[4] = in_regs[53]^in_regs[34]^datain[4];
assign scramb_outs[5] = in_regs[52]^in_regs[33]^datain[5];
assign scramb_outs[6] = in_regs[51]^in_regs[32]^datain[6];
assign scramb_outs[7] = in_regs[50]^in_regs[31]^datain[7];
assign scramb_outs[8] = in_regs[49]^in_regs[30]^datain[8];
assign scramb_outs[9] = in_regs[48]^in_regs[29]^datain[9];
assign scramb_outs[10] = in_regs[47]^in_regs[28]^datain[10];
assign scramb_outs[11] = in_regs[46]^in_regs[27]^datain[11];
assign scramb_outs[12] = in_regs[45]^in_regs[26]^datain[12];
assign scramb_outs[13] = in_regs[44]^in_regs[25]^datain[13];
assign scramb_outs[14] = in_regs[43]^in_regs[24]^datain[14];
assign scramb_outs[15] = in_regs[42]^in_regs[23]^datain[15];
assign scramb_outs[16] = in_regs[41]^in_regs[22]^datain[16];
assign scramb_outs[17] = in_regs[40]^in_regs[21]^datain[17];
assign scramb_outs[18] = in_regs[39]^in_regs[20]^datain[18];
assign scramb_outs[19] = in_regs[38]^in_regs[19]^datain[19];
assign scramb_outs[20] = in_regs[37]^in_regs[18]^datain[20];
assign scramb_outs[21] = in_regs[36]^in_regs[17]^datain[21];
assign scramb_outs[22] = in_regs[35]^in_regs[16]^datain[22];
assign scramb_outs[23] = in_regs[34]^in_regs[15]^datain[23];
assign scramb_outs[24] = in_regs[33]^in_regs[14]^datain[24];
assign scramb_outs[25] = in_regs[32]^in_regs[13]^datain[25];
assign scramb_outs[26] = in_regs[31]^in_regs[12]^datain[26];
assign scramb_outs[27] = in_regs[30]^in_regs[11]^datain[27];
assign scramb_outs[28] = in_regs[29]^in_regs[10]^datain[28];
assign scramb_outs[29] = in_regs[28]^in_regs[9]^datain[29];
assign scramb_outs[30] = in_regs[27]^in_regs[8]^datain[30];
assign scramb_outs[31] = in_regs[26]^in_regs[7]^datain[31];
assign scramb_outs[32] = in_regs[25]^in_regs[6]^datain[32];
assign scramb_outs[33] = in_regs[24]^in_regs[5]^datain[33];
assign scramb_outs[34] = in_regs[23]^in_regs[4]^datain[34];
assign scramb_outs[35] = in_regs[22]^in_regs[3]^datain[35];
assign scramb_outs[36] = in_regs[21]^in_regs[2]^datain[36];
assign scramb_outs[37] = in_regs[20]^in_regs[1]^datain[37];
assign scramb_outs[38] = in_regs[19]^in_regs[0]^datain[38];
assign scramb_outs[39] = in_regs[18]^(in_regs[57]^in_regs[38]^datain[0])^datain[39];
assign scramb_outs[40] = in_regs[17]^(in_regs[56]^in_regs[37]^datain[1])^datain[40];
assign scramb_outs[41] = in_regs[16]^(in_regs[55]^in_regs[36]^datain[2])^datain[41];
assign scramb_outs[42] = in_regs[15]^(in_regs[54]^in_regs[35]^datain[3])^datain[42];
assign scramb_outs[43] = in_regs[14]^(in_regs[53]^in_regs[34]^datain[4])^datain[43];
assign scramb_outs[44] = in_regs[13]^(in_regs[52]^in_regs[33]^datain[5])^datain[44];
assign scramb_outs[45] = in_regs[12]^(in_regs[51]^in_regs[32]^datain[6])^datain[45];
assign scramb_outs[46] = in_regs[11]^(in_regs[50]^in_regs[31]^datain[7])^datain[46];
assign scramb_outs[47] = in_regs[10]^(in_regs[49]^in_regs[30]^datain[8])^datain[47];
assign scramb_outs[48] = in_regs[9]^(in_regs[48]^in_regs[29]^datain[9])^datain[48];
assign scramb_outs[49] = in_regs[8]^(in_regs[47]^in_regs[28]^datain[10])^datain[49];
assign scramb_outs[50] = in_regs[7]^(in_regs[46]^in_regs[27]^datain[11])^datain[50];
assign scramb_outs[51] = in_regs[6]^(in_regs[45]^in_regs[26]^datain[12])^datain[51];
assign scramb_outs[52] = in_regs[5]^(in_regs[44]^in_regs[25]^datain[13])^datain[52];
assign scramb_outs[53] = in_regs[4]^(in_regs[43]^in_regs[24]^datain[14])^datain[53];
assign scramb_outs[54] = in_regs[3]^(in_regs[42]^in_regs[23]^datain[15])^datain[54];
assign scramb_outs[55] = in_regs[2]^(in_regs[41]^in_regs[22]^datain[16])^datain[55];
assign scramb_outs[56] = in_regs[1]^(in_regs[40]^in_regs[21]^datain[17])^datain[56];
assign scramb_outs[57] = in_regs[0]^(in_regs[39]^in_regs[20]^datain[18])^datain[57];
assign scramb_outs[58] = (in_regs[57]^datain[0])^(in_regs[19]^datain[19])^datain[58];
assign scramb_outs[59] = (in_regs[56]^datain[1])^(in_regs[18]^datain[20])^datain[59];
assign scramb_outs[60] = (in_regs[55]^datain[2])^(in_regs[17]^datain[21])^datain[60];
assign scramb_outs[61] = (in_regs[54]^datain[3])^(in_regs[16]^datain[22])^datain[61];
assign scramb_outs[62] = (in_regs[53]^datain[4])^(in_regs[15]^datain[23])^datain[62];
assign scramb_outs[63] = (in_regs[52]^datain[5])^(in_regs[14]^datain[24])^datain[63];

 				
 // assignment of the intermediate registers, scrambling(if enabled) or bypassing (if enabled)
 always @ (posedge clock or posedge reset) begin
	if (reset == 1'b1) begin												
			in_regs 	<= {58{1'b1}};
			dataout 	<= {{64{1'b0}}, 2'b10};	
		   	datain 		<= {64{1'b1}};
			sync_header 	<= 2'b10;
	end
	else if (scram_enable == 1'b0) begin	 			// scrambler is not enabled
			datain 		  <= datain;
			sync_header	  <= sync_header;
			in_regs 	  <= in_regs;
			dataout 	  <= dataout;				
	end
	else if (bypass_enable == 1'b1) begin		     // bypass mode 
			datain[63:0]	  <= data_in[65:2];
			sync_header[1:0]  <= data_in[1:0];
			dataout[65:0] 	  <= {datain, sync_header};
			in_regs 	  <= in_regs;					
	end
	else begin	
			sync_header[1:0]  <= data_in[1:0];
			datain[63:0] 	  <= data_in[65:2];
			dataout[65:0] 	  <= {scramb_outs[63:0], sync_header[1:0]};	
								
			in_regs[57] <= scramb_outs[6];
			in_regs[56] <= scramb_outs[7];
			in_regs[55] <= scramb_outs[8];
			in_regs[54] <= scramb_outs[9];
			in_regs[53] <= scramb_outs[10];
			in_regs[52] <= scramb_outs[11];
			in_regs[51] <= scramb_outs[12];
			in_regs[50] <= scramb_outs[13];
			in_regs[49] <= scramb_outs[14];
			in_regs[48] <= scramb_outs[15];
			in_regs[47] <= scramb_outs[16];
			in_regs[46] <= scramb_outs[17];
			in_regs[45] <= scramb_outs[18];
			in_regs[44] <= scramb_outs[19];
			in_regs[43] <= scramb_outs[20];
			in_regs[42] <= scramb_outs[21];
			in_regs[41] <= scramb_outs[22];
			in_regs[40] <= scramb_outs[23];
			in_regs[39] <= scramb_outs[24];
			in_regs[38] <= scramb_outs[25];
			in_regs[37] <= scramb_outs[26];
			in_regs[36] <= scramb_outs[27];
			in_regs[35] <= scramb_outs[28];
			in_regs[34] <= scramb_outs[29];
			in_regs[33] <= scramb_outs[30];
			in_regs[32] <= scramb_outs[31];
			in_regs[31] <= scramb_outs[32];
			in_regs[30] <= scramb_outs[33];
			in_regs[29] <= scramb_outs[34];
			in_regs[28] <= scramb_outs[35];
			in_regs[27] <= scramb_outs[36];
			in_regs[26] <= scramb_outs[37];
			in_regs[25] <= scramb_outs[38];
			in_regs[24] <= scramb_outs[39];
			in_regs[23] <= scramb_outs[40];
			in_regs[22] <= scramb_outs[41];
			in_regs[21] <= scramb_outs[42];
			in_regs[20] <= scramb_outs[43];
			in_regs[19] <= scramb_outs[44];
			in_regs[18] <= scramb_outs[45];
			in_regs[17] <= scramb_outs[46];
			in_regs[16] <= scramb_outs[47];
			in_regs[15] <= scramb_outs[48];
			in_regs[14] <= scramb_outs[49];
			in_regs[13] <= scramb_outs[50];
			in_regs[12] <= scramb_outs[51];
			in_regs[11] <= scramb_outs[52];
			in_regs[10] <= scramb_outs[53];
			in_regs[9] <= scramb_outs[54];
			in_regs[8] <= scramb_outs[55];
			in_regs[7] <= scramb_outs[56];
			in_regs[6] <= scramb_outs[57];
			in_regs[5] <= scramb_outs[58];
			in_regs[4] <= scramb_outs[59];
			in_regs[3] <= scramb_outs[60];
			in_regs[2] <= scramb_outs[61];
			in_regs[1] <= scramb_outs[62];
			in_regs[0] <= scramb_outs[63];
	end
 end

endmodule


//=============== POLYNOMIALS ======================================
// Linear Feedback Shift Register polynomials; + is exclusive OR;
// Derived from serial implementation transiting 64 clock cycles
//------------------------------------------------------------
////x_57(63)= x_51 + x_32 + d_6
////x_56(63)= x_50 + x_31 + d_7
////x_55(63)= x_49 + x_30 + d_8
////x_54(63)= x_48 + x_29 + d_9
////x_53(63)= x_47 + x_28 + d_10
////x_52(63)= x_46 + x_27 + d_11
////x_51(63)= x_45 + x_26 + d_12
////x_50(63)= x_44 + x_25 + d_13
////x_49(63)= x_43 + x_24 + d_14
////x_48(63)= x_42 + x_23 + d_15
////x_47(63)= x_41 + x_22 + d_16
////x_46(63)= x_40 + x_21 + d_17
////x_45(63)= x_39 + x_20 + d_18
////x_44(63)= x_38 + x_19 + d_19
////x_43(63)= x_37 + x_18 + d_20
////x_42(63)= x_36 + x_17 + d_21
////x_41(63)= x_35 + x_16 + d_22
////x_40(63)= x_34 + x_15 + d_23
////x_39(63)= x_33 + x_14 + d_24
////x_38(63)= x_32 + x_13 + d_25
////x_37(63)= x_31 + x_12 + d_26
////x_36(63)= x_30 + x_11 + d_27
////x_35(63)= x_29 + x_10 + d_28
////x_34(63)= x_28 + x_9 + d_29
////x_33(63)= x_27 + x_8 + d_30
////x_32(63)= x_26 + x_7 + d_31
////x_31(63)= x_25 + x_6 + d_32
////x_30(63)= x_24 + x_5 + d_33
////x_29(63)= x_23 + x_4 + d_34
////x_28(63)= x_22 + x_3 + d_35
////x_27(63)= x_21 + x_2 + d_36
////x_26(63)= x_20 + x_1 + d_37
////x_25(63)= x_19 + x_0 + d_38
////x_24(63)= x_18 + x_57 + x_38 + d_0 + d_39
////x_23(63)= x_17 + x_56 + x_37 + d_1 + d_40
////x_22(63)= x_16 + x_55 + x_36 + d_2 + d_41
////x_21(63)= x_15 + x_54 + x_35 + d_3 + d_42
////x_20(63)= x_14 + x_53 + x_34 + d_4 + d_43
////x_19(63)= x_13 + x_52 + x_33 + d_5 + d_44
////x_18(63)= x_12 + x_51 + x_32 + d_6 + d_45
////x_17(63)= x_11 + x_50 + x_31 + d_7 + d_46
////x_16(63)= x_10 + x_49 + x_30 + d_8 + d_47
////x_15(63)= x_9 + x_48 + x_29 + d_9 + d_48
////x_14(63)= x_8 + x_47 + x_28 + d_10 + d_49
////x_13(63)= x_7 + x_46 + x_27 + d_11 + d_50
////x_12(63)= x_6 + x_45 + x_26 + d_12 + d_51
////x_11(63)= x_5 + x_44 + x_25 + d_13 + d_52
////x_10(63)= x_4 + x_43 + x_24 + d_14 + d_53
////x_9(63)= x_3 + x_42 + x_23 + d_15 + d_54
////x_8(63)= x_2 + x_41 + x_22 + d_16 + d_55
////x_7(63)= x_1 + x_40 + x_21 + d_17 + d_56
////x_6(63)= x_0 + x_39 + x_20 + d_18 + d_57
////x_5(63)= x_57 + x_38 + d_0 + x_38 + x_19 + d_19 + d_58
////x_4(63)= x_56 + x_37 + d_1 + x_37 + x_18 + d_20 + d_59
////x_3(63)= x_55 + x_36 + d_2 + x_36 + x_17 + d_21 + d_60
////x_2(63)= x_54 + x_35 + d_3 + x_35 + x_16 + d_22 + d_61
////x_1(63)= x_53 + x_34 + d_4 + x_34 + x_15 + d_23 + d_62
////x_0(63)= x_52 + x_33 + d_5 + x_33 + x_14 + d_24 + d_63

//--------------------------------------------------------
// Output values: 64-bit register
// derived from serial implementation transiting 64 clock cycles
//--------------------------------------------------------
////out_0(63)= x_57 + x_38 + d_0
////out_1(63)= x_56 + x_37 + d_1
////out_2(63)= x_55 + x_36 + d_2
////out_3(63)= x_54 + x_35 + d_3
////out_4(63)= x_53 + x_34 + d_4
////out_5(63)= x_52 + x_33 + d_5
////out_6(63)= x_51 + x_32 + d_6
////out_7(63)= x_50 + x_31 + d_7
////out_8(63)= x_49 + x_30 + d_8
////out_9(63)= x_48 + x_29 + d_9
////out_10(63)= x_47 + x_28 + d_10
////out_11(63)= x_46 + x_27 + d_11
////out_12(63)= x_45 + x_26 + d_12
////out_13(63)= x_44 + x_25 + d_13
////out_14(63)= x_43 + x_24 + d_14
////out_15(63)= x_42 + x_23 + d_15
////out_16(63)= x_41 + x_22 + d_16
////out_17(63)= x_40 + x_21 + d_17
////out_18(63)= x_39 + x_20 + d_18
////out_19(63)= x_38 + x_19 + d_19
////out_20(63)= x_37 + x_18 + d_20
////out_21(63)= x_36 + x_17 + d_21
////out_22(63)= x_35 + x_16 + d_22
////out_23(63)= x_34 + x_15 + d_23
////out_24(63)= x_33 + x_14 + d_24
////out_25(63)= x_32 + x_13 + d_25
////out_26(63)= x_31 + x_12 + d_26
////out_27(63)= x_30 + x_11 + d_27
////out_28(63)= x_29 + x_10 + d_28
////out_29(63)= x_28 + x_9 + d_29
////out_30(63)= x_27 + x_8 + d_30
////out_31(63)= x_26 + x_7 + d_31
////out_32(63)= x_25 + x_6 + d_32
////out_33(63)= x_24 + x_5 + d_33
////out_34(63)= x_23 + x_4 + d_34
////out_35(63)= x_22 + x_3 + d_35
////out_36(63)= x_21 + x_2 + d_36
////out_37(63)= x_20 + x_1 + d_37
////out_38(63)= x_19 + x_0 + d_38
////out_39(63)= x_18 + x_57 + x_38 + d_0 + d_39
////out_40(63)= x_17 + x_56 + x_37 + d_1 + d_40
////out_41(63)= x_16 + x_55 + x_36 + d_2 + d_41
////out_42(63)= x_15 + x_54 + x_35 + d_3 + d_42
////out_43(63)= x_14 + x_53 + x_34 + d_4 + d_43
////out_44(63)= x_13 + x_52 + x_33 + d_5 + d_44
////out_45(63)= x_12 + x_51 + x_32 + d_6 + d_45
////out_46(63)= x_11 + x_50 + x_31 + d_7 + d_46
////out_47(63)= x_10 + x_49 + x_30 + d_8 + d_47
////out_48(63)= x_9 + x_48 + x_29 + d_9 + d_48
////out_49(63)= x_8 + x_47 + x_28 + d_10 + d_49
////out_50(63)= x_7 + x_46 + x_27 + d_11 + d_50
////out_51(63)= x_6 + x_45 + x_26 + d_12 + d_51
////out_52(63)= x_5 + x_44 + x_25 + d_13 + d_52
////out_53(63)= x_4 + x_43 + x_24 + d_14 + d_53
////out_54(63)= x_3 + x_42 + x_23 + d_15 + d_54
////out_55(63)= x_2 + x_41 + x_22 + d_16 + d_55
////out_56(63)= x_1 + x_40 + x_21 + d_17 + d_56
////out_57(63)= x_0 + x_39 + x_20 + d_18 + d_57
////out_58(63)= x_57 + x_38 + d_0 + x_38 + x_19 + d_19 + d_58
////out_59(63)= x_56 + x_37 + d_1 + x_37 + x_18 + d_20 + d_59
////out_60(63)= x_55 + x_36 + d_2 + x_36 + x_17 + d_21 + d_60
////out_61(63)= x_54 + x_35 + d_3 + x_35 + x_16 + d_22 + d_61
////out_62(63)= x_53 + x_34 + d_4 + x_34 + x_15 + d_23 + d_62
////out_63(63)= x_52 + x_33 + d_5 + x_33 + x_14 + d_24 + d_63



