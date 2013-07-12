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
// Description: Descrambler decodes POLY encoded sequences to 10GBASE-R representation. 
// POLY used: G(x) = X^58 + X^39 + 1; All equations can be derived from the serial 
// descrambler implementation. Descrambler module requires alignment of word boundaries 
// at the times when words are processed.
// The module comes without training procedure implemented.
//////////////////////////////////////////////////////////////////////////////////
module descrambler_parallel(datain, dataout, descram_enable, din_synched, bypass_enable, dout_synched, reset, clock);
 
 input wire [65:0] datain;				// sync header + data from encoder
 input wire reset;					
 input wire clock;					
 input wire descram_enable;			// enable scrambler, if disabled - send previous state
 input wire bypass_enable;				// bypass scrambler, if enabled - send unscrambled data
 input wire din_synched;				// check whether input is a correctly framed word	 

 output reg [65:0] dataout;			// synch header + scrambled data
 output reg dout_synched;				// output synch status
 
////////////////////////////////////////////////////////////////
 reg [63:0] descramb_outs;		
 reg [57:0] intm_regs;				
 reg [63:0] datain_wr;			
 reg [1:0]  de_sync_header;		
 	
 //---------------------------------------------------------------------
 // descramble outs - polinomials are presented below
always @ (*) begin
	if (reset) begin
	  descramb_outs = 'b0;	
	end		
	else begin
	  descramb_outs[0] = intm_regs[57]^intm_regs[38]^datain_wr[0];		
	  descramb_outs[1] = intm_regs[56]^intm_regs[37]^datain_wr[1];		
	  descramb_outs[2] = intm_regs[55]^intm_regs[36]^datain_wr[2];
 	  descramb_outs[3] = intm_regs[54]^intm_regs[35]^datain_wr[3];
 	  descramb_outs[4] = intm_regs[53]^intm_regs[34]^datain_wr[4];
 	  descramb_outs[5] = intm_regs[52]^intm_regs[33]^datain_wr[5];	
 	  descramb_outs[6] = intm_regs[51]^intm_regs[32]^datain_wr[6];
 	  descramb_outs[7] = intm_regs[50]^intm_regs[31]^datain_wr[7];
 	  descramb_outs[8] = intm_regs[49]^intm_regs[30]^datain_wr[8];
 	  descramb_outs[9] = intm_regs[48]^intm_regs[29]^datain_wr[9];
 	  descramb_outs[10] = intm_regs[47]^intm_regs[28]^datain_wr[10];
 	  descramb_outs[11] = intm_regs[46]^intm_regs[27]^datain_wr[11];
 	  descramb_outs[12] = intm_regs[45]^intm_regs[26]^datain_wr[12];
 	  descramb_outs[13] = intm_regs[44]^intm_regs[25]^datain_wr[13];
 	  descramb_outs[14] = intm_regs[43]^intm_regs[24]^datain_wr[14];
 	  descramb_outs[15] = intm_regs[42]^intm_regs[23]^datain_wr[15];
 	  descramb_outs[16] = intm_regs[41]^intm_regs[22]^datain_wr[16];
 	  descramb_outs[17] = intm_regs[40]^intm_regs[21]^datain_wr[17];
 	  descramb_outs[18] = intm_regs[39]^intm_regs[20]^datain_wr[18];
 	  descramb_outs[19] = intm_regs[38]^intm_regs[19]^datain_wr[19];
 	  descramb_outs[20] = intm_regs[37]^intm_regs[18]^datain_wr[20];
 	  descramb_outs[21] = intm_regs[36]^intm_regs[17]^datain_wr[21];
 	  descramb_outs[22] = intm_regs[35]^intm_regs[16]^datain_wr[22];
 	  descramb_outs[23] = intm_regs[34]^intm_regs[15]^datain_wr[23];
 	  descramb_outs[24] = intm_regs[33]^intm_regs[14]^datain_wr[24];
 	  descramb_outs[25] = intm_regs[32]^intm_regs[13]^datain_wr[25];
 	  descramb_outs[26] = intm_regs[31]^intm_regs[12]^datain_wr[26];
 	  descramb_outs[27] = intm_regs[30]^intm_regs[11]^datain_wr[27];
 	  descramb_outs[28] = intm_regs[29]^intm_regs[10]^datain_wr[28];
 	  descramb_outs[29] = intm_regs[28]^intm_regs[9]^datain_wr[29];
 	  descramb_outs[30] = intm_regs[27]^intm_regs[8]^datain_wr[30];
 	  descramb_outs[31] = intm_regs[26]^intm_regs[7]^datain_wr[31];
 	  descramb_outs[32] = intm_regs[25]^intm_regs[6]^datain_wr[32];
 	  descramb_outs[33] = intm_regs[24]^intm_regs[5]^datain_wr[33];
 	  descramb_outs[34] = intm_regs[23]^intm_regs[4]^datain_wr[34];
 	  descramb_outs[35] = intm_regs[22]^intm_regs[3]^datain_wr[35];
 	  descramb_outs[36] = intm_regs[21]^intm_regs[2]^datain_wr[36];
 	  descramb_outs[37] = intm_regs[20]^intm_regs[1]^datain_wr[37];
 	  descramb_outs[38] = intm_regs[19]^intm_regs[0]^datain_wr[38];				
 	  descramb_outs[39] = intm_regs[18]^datain_wr[0]^datain_wr[39];
 	  descramb_outs[40] = intm_regs[17]^datain_wr[1]^datain_wr[40];
 	  descramb_outs[41] = intm_regs[16]^datain_wr[2]^datain_wr[41];
 	  descramb_outs[42] = intm_regs[15]^datain_wr[3]^datain_wr[42];
 	  descramb_outs[43] = intm_regs[14]^datain_wr[4]^datain_wr[43];
 	  descramb_outs[44] = intm_regs[13]^datain_wr[5]^datain_wr[44];
 	  descramb_outs[45] = intm_regs[12]^datain_wr[6]^datain_wr[45];
 	  descramb_outs[46] = intm_regs[11]^datain_wr[7]^datain_wr[46];
 	  descramb_outs[47] = intm_regs[10]^datain_wr[8]^datain_wr[47];
 	  descramb_outs[48] = intm_regs[9]^datain_wr[9]^datain_wr[48];
 	  descramb_outs[49] = intm_regs[8]^datain_wr[10]^datain_wr[49];
 	  descramb_outs[50] = intm_regs[7]^datain_wr[11]^datain_wr[50];
 	  descramb_outs[51] = intm_regs[6]^datain_wr[12]^datain_wr[51];
 	  descramb_outs[52] = intm_regs[5]^datain_wr[13]^datain_wr[52];
 	  descramb_outs[53] = intm_regs[4]^datain_wr[14]^datain_wr[53];
 	  descramb_outs[54] = intm_regs[3]^datain_wr[15]^datain_wr[54];
 	  descramb_outs[55] = intm_regs[2]^datain_wr[16]^datain_wr[55];
 	  descramb_outs[56] = intm_regs[1]^datain_wr[17]^datain_wr[56];
 	  descramb_outs[57] = intm_regs[0]^datain_wr[18]^datain_wr[57];
 	  descramb_outs[58] = datain_wr[0]^datain_wr[19]^datain_wr[58];
 	  descramb_outs[59] = datain_wr[1]^datain_wr[20]^datain_wr[59];
 	  descramb_outs[60] = datain_wr[2]^datain_wr[21]^datain_wr[60];
 	  descramb_outs[61] = datain_wr[3]^datain_wr[22]^datain_wr[61];
 	  descramb_outs[62] = datain_wr[4]^datain_wr[23]^datain_wr[62];
 	  descramb_outs[63] = datain_wr[5]^datain_wr[24]^datain_wr[63];
	end
end
				
 // assignment of the intermediate registers, descrambling(if enabled) or bypassing (if enabled)
 // 2 maijor questions - 1) in normal mode initialization of regs, 2) check locking
 always @ (posedge clock or posedge reset) begin
		if (reset) begin												// reset to default values
				intm_regs	    <= {58{1'b1}};		
				dataout 	    <= {{64{1'b0}}, 2'b10};	
				datain_wr 	    <= {64{1'b0}};
				de_sync_header      <= 2'b10;
				dout_synched	    <= 1'b0;	 	
				
		end
		else if (descram_enable == 1'b0) begin								// scrambler is not enabled
				datain_wr[63:0] 	<= datain[65:2];
				de_sync_header[1:0] 	<= datain[1:0];
				intm_regs		<= intm_regs;
				dataout[65:0]		<= dataout[65:0];
				dout_synched	    	<= din_synched;				
		end
		else if (bypass_enable == 1'b1) begin								// bypass option is enabled
				datain_wr[63:0] 	<= datain[65:2];
				de_sync_header[1:0] 	<= datain[1:0];
				dataout[65:0] 		<= {datain_wr, de_sync_header};				
				intm_regs		<= intm_regs;
				dout_synched	    	<= din_synched;
		end
		else begin														// assignment of intermediate regs and scrambled outs
				datain_wr[63:0] 	<= datain[65:2];
				de_sync_header[1:0] <= datain[1:0];
				dataout[65:0] 		<= {descramb_outs[63:0], de_sync_header[1:0]};
				dout_synched	    	<= din_synched;	
				
				intm_regs[57] <= datain_wr[6];
				intm_regs[56] <= datain_wr[7];
				intm_regs[55] <= datain_wr[8];
				intm_regs[54] <= datain_wr[9];
				intm_regs[53] <= datain_wr[10];
				intm_regs[52] <= datain_wr[11];
				intm_regs[51] <= datain_wr[12];
				intm_regs[50] <= datain_wr[13];
				intm_regs[49] <= datain_wr[14];
				intm_regs[48] <= datain_wr[15];
				intm_regs[47] <= datain_wr[16];
				intm_regs[46] <= datain_wr[17];
				intm_regs[45] <= datain_wr[18];
				intm_regs[44] <= datain_wr[19];
				intm_regs[43] <= datain_wr[20];
				intm_regs[42] <= datain_wr[21];
				intm_regs[41] <= datain_wr[22];
				intm_regs[40] <= datain_wr[23];
				intm_regs[39] <= datain_wr[24];
				intm_regs[38] <= datain_wr[25];
				intm_regs[37] <= datain_wr[26];
				intm_regs[36] <= datain_wr[27];
				intm_regs[35] <= datain_wr[28];
				intm_regs[34] <= datain_wr[29];
				intm_regs[33] <= datain_wr[30];
				intm_regs[32] <= datain_wr[31];
				intm_regs[31] <= datain_wr[32];
				intm_regs[30] <= datain_wr[33];
				intm_regs[29] <= datain_wr[34];
				intm_regs[28] <= datain_wr[35];
				intm_regs[27] <= datain_wr[36];
				intm_regs[26] <= datain_wr[37];
				intm_regs[25] <= datain_wr[38];
				intm_regs[24] <= datain_wr[39];
				intm_regs[23] <= datain_wr[40];
				intm_regs[22] <= datain_wr[41];
				intm_regs[21] <= datain_wr[42];
				intm_regs[20] <= datain_wr[43];
				intm_regs[19] <= datain_wr[44];
				intm_regs[18] <= datain_wr[45];
				intm_regs[17] <= datain_wr[46];
				intm_regs[16] <= datain_wr[47];
				intm_regs[15] <= datain_wr[48];
				intm_regs[14] <= datain_wr[49];
				intm_regs[13] <= datain_wr[50];
				intm_regs[12] <= datain_wr[51];
				intm_regs[11] <= datain_wr[52];
				intm_regs[10] <= datain_wr[53];
				intm_regs[9] <= datain_wr[54];
				intm_regs[8] <= datain_wr[55];
				intm_regs[7] <= datain_wr[56];
				intm_regs[6] <= datain_wr[57];
				intm_regs[5] <= datain_wr[58];
				intm_regs[4] <= datain_wr[59];
				intm_regs[3] <= datain_wr[60];
				intm_regs[2] <= datain_wr[61];
				intm_regs[1] <= datain_wr[62];
				intm_regs[0] <= datain_wr[63];
		end		
   end

endmodule
/*
assign descramb_outs[0] = intm_regs[57]^intm_regs[38]^datain_wr[0];		
	assign descramb_outs[1] = intm_regs[56]^intm_regs[37]^datain_wr[1];		
	assign descramb_outs[2] = intm_regs[55]^intm_regs[36]^datain_wr[2];
 	assign descramb_outs[3] = intm_regs[54]^intm_regs[35]^datain_wr[3];
 	assign descramb_outs[4] = intm_regs[53]^intm_regs[34]^datain_wr[4];
 	assign descramb_outs[5] = intm_regs[52]^intm_regs[33]^datain_wr[5];	
 	assign descramb_outs[6] = intm_regs[51]^intm_regs[32]^datain_wr[6];
 	assign descramb_outs[7] = intm_regs[50]^intm_regs[31]^datain_wr[7];
 	assign descramb_outs[8] = intm_regs[49]^intm_regs[30]^datain_wr[8];
 	assign descramb_outs[9] = intm_regs[48]^intm_regs[29]^datain_wr[9];
 	assign descramb_outs[10] = intm_regs[47]^intm_regs[28]^datain_wr[10];
 	assign descramb_outs[11] = intm_regs[46]^intm_regs[27]^datain_wr[11];
 	assign descramb_outs[12] = intm_regs[45]^intm_regs[26]^datain_wr[12];
 	assign descramb_outs[13] = intm_regs[44]^intm_regs[25]^datain_wr[13];
 	assign descramb_outs[14] = intm_regs[43]^intm_regs[24]^datain_wr[14];
 	assign descramb_outs[15] = intm_regs[42]^intm_regs[23]^datain_wr[15];
 	assign descramb_outs[16] = intm_regs[41]^intm_regs[22]^datain_wr[16];
 	assign descramb_outs[17] = intm_regs[40]^intm_regs[21]^datain_wr[17];
 	assign descramb_outs[18] = intm_regs[39]^intm_regs[20]^datain_wr[18];
 	assign descramb_outs[19] = intm_regs[38]^intm_regs[19]^datain_wr[19];
 	assign descramb_outs[20] = intm_regs[37]^intm_regs[18]^datain_wr[20];
 	assign descramb_outs[21] = intm_regs[36]^intm_regs[17]^datain_wr[21];
 	assign descramb_outs[22] = intm_regs[35]^intm_regs[16]^datain_wr[22];
 	assign descramb_outs[23] = intm_regs[34]^intm_regs[15]^datain_wr[23];
 	assign descramb_outs[24] = intm_regs[33]^intm_regs[14]^datain_wr[24];
 	assign descramb_outs[25] = intm_regs[32]^intm_regs[13]^datain_wr[25];
 	assign descramb_outs[26] = intm_regs[31]^intm_regs[12]^datain_wr[26];
 	assign descramb_outs[27] = intm_regs[30]^intm_regs[11]^datain_wr[27];
 	assign descramb_outs[28] = intm_regs[29]^intm_regs[10]^datain_wr[28];
 	assign descramb_outs[29] = intm_regs[28]^intm_regs[9]^datain_wr[29];
 	assign descramb_outs[30] = intm_regs[27]^intm_regs[8]^datain_wr[30];
 	assign descramb_outs[31] = intm_regs[26]^intm_regs[7]^datain_wr[31];
 	assign descramb_outs[32] = intm_regs[25]^intm_regs[6]^datain_wr[32];
 	assign descramb_outs[33] = intm_regs[24]^intm_regs[5]^datain_wr[33];
 	assign descramb_outs[34] = intm_regs[23]^intm_regs[4]^datain_wr[34];
 	assign descramb_outs[35] = intm_regs[22]^intm_regs[3]^datain_wr[35];
 	assign descramb_outs[36] = intm_regs[21]^intm_regs[2]^datain_wr[36];
 	assign descramb_outs[37] = intm_regs[20]^intm_regs[1]^datain_wr[37];
 	assign descramb_outs[38] = intm_regs[19]^intm_regs[0]^datain_wr[38];				
 	assign descramb_outs[39] = intm_regs[18]^datain_wr[0]^datain_wr[39];
 	assign descramb_outs[40] = intm_regs[17]^datain_wr[1]^datain_wr[40];
 	assign descramb_outs[41] = intm_regs[16]^datain_wr[2]^datain_wr[41];
 	assign descramb_outs[42] = intm_regs[15]^datain_wr[3]^datain_wr[42];
 	assign descramb_outs[43] = intm_regs[14]^datain_wr[4]^datain_wr[43];
 	assign descramb_outs[44] = intm_regs[13]^datain_wr[5]^datain_wr[44];
 	assign descramb_outs[45] = intm_regs[12]^datain_wr[6]^datain_wr[45];
 	assign descramb_outs[46] = intm_regs[11]^datain_wr[7]^datain_wr[46];
 	assign descramb_outs[47] = intm_regs[10]^datain_wr[8]^datain_wr[47];
 	assign descramb_outs[48] = intm_regs[9]^datain_wr[9]^datain_wr[48];
 	assign descramb_outs[49] = intm_regs[8]^datain_wr[10]^datain_wr[49];
 	assign descramb_outs[50] = intm_regs[7]^datain_wr[11]^datain_wr[50];
 	assign descramb_outs[51] = intm_regs[6]^datain_wr[12]^datain_wr[51];
 	assign descramb_outs[52] = intm_regs[5]^datain_wr[13]^datain_wr[52];
 	assign descramb_outs[53] = intm_regs[4]^datain_wr[14]^datain_wr[53];
 	assign descramb_outs[54] = intm_regs[3]^datain_wr[15]^datain_wr[54];
 	assign descramb_outs[55] = intm_regs[2]^datain_wr[16]^datain_wr[55];
 	assign descramb_outs[56] = intm_regs[1]^datain_wr[17]^datain_wr[56];
 	assign descramb_outs[57] = intm_regs[0]^datain_wr[18]^datain_wr[57];
 	assign descramb_outs[58] = datain_wr[0]^datain_wr[19]^datain_wr[58];
 	assign descramb_outs[59] = datain_wr[1]^datain_wr[20]^datain_wr[59];
 	assign descramb_outs[60] = datain_wr[2]^datain_wr[21]^datain_wr[60];
 	assign descramb_outs[61] = datain_wr[3]^datain_wr[22]^datain_wr[61];
 	assign descramb_outs[62] = datain_wr[4]^datain_wr[23]^datain_wr[62];
 	assign descramb_outs[63] = datain_wr[5]^datain_wr[24]^datain_wr[63];
*/

//=============== POLYNOMIALS ======================================
// Linear Feedback Shift Register polynomials; + is exclusive OR;
// Derived from serial implementation transiting 64 clock cycles
//------------------------------------------------------------
////x^57(63)= d_in6
////x^56(63)= d_in7
////x^55(63)= d_in8
////x^54(63)= d_in9
////x^53(63)= d_in10
////x^52(63)= d_in11
////x^51(63)= d_in12
////x^50(63)= d_in13
////x^49(63)= d_in14
////x^48(63)= d_in15
////x^47(63)= d_in16
////x^46(63)= d_in17
////x^45(63)= d_in18
////x^44(63)= d_in19
////x^43(63)= d_in20
////x^42(63)= d_in21
////x^41(63)= d_in22
////x^40(63)= d_in23
////x^39(63)= d_in24
////x^38(63)= d_in25
////x^37(63)= d_in26
////x^36(63)= d_in27
////x^35(63)= d_in28
////x^34(63)= d_in29
////x^33(63)= d_in30
////x^32(63)= d_in31
////x^31(63)= d_in32
////x^30(63)= d_in33
////x^29(63)= d_in34
////x^28(63)= d_in35
////x^27(63)= d_in36
////x^26(63)= d_in37
////x^25(63)= d_in38
////x^24(63)= d_in39
////x^23(63)= d_in40
////x^22(63)= d_in41
////x^21(63)= d_in42
////x^20(63)= d_in43
////x^19(63)= d_in44
////x^18(63)= d_in45
////x^17(63)= d_in46
////x^16(63)= d_in47
////x^15(63)= d_in48
////x^14(63)= d_in49
////x^13(63)= d_in50
////x^12(63)= d_in51
////x^11(63)= d_in52
////x^10(63)= d_in53
////x^9(63)= d_in54
////x^8(63)= d_in55
////x^7(63)= d_in56
////x^6(63)= d_in57
////x^5(63)= d_in58
////x^4(63)= d_in59
////x^3(63)= d_in60
////x^2(63)= d_in61
////x^1(63)= d_in62
////x^0(63)= d_in63
//--------------------------------------------------------
// Output values: 64-bit register
// derived from serial implementation transiting 64 clock cycles
//--------------------------------------------------------
////out_0(63)= x^57 + x^38 + d_in0
////out_1(63)= x^56 + x^37 + d_in1
////out_2(63)= x^55 + x^36 + d_in2
////out_3(63)= x^54 + x^35 + d_in3
////out_4(63)= x^53 + x^34 + d_in4
////out_5(63)= x^52 + x^33 + d_in5
////out_6(63)= x^51 + x^32 + d_in6
////out_7(63)= x^50 + x^31 + d_in7
////out_8(63)= x^49 + x^30 + d_in8
////out_9(63)= x^48 + x^29 + d_in9
////out_10(63)= x^47 + x^28 + d_in10
////out_11(63)= x^46 + x^27 + d_in11
////out_12(63)= x^45 + x^26 + d_in12
////out_13(63)= x^44 + x^25 + d_in13
////out_14(63)= x^43 + x^24 + d_in14
////out_15(63)= x^42 + x^23 + d_in15
////out_16(63)= x^41 + x^22 + d_in16
////out_17(63)= x^40 + x^21 + d_in17
////out_18(63)= x^39 + x^20 + d_in18
////out_19(63)= x^38 + x^19 + d_in19
////out_20(63)= x^37 + x^18 + d_in20
////out_21(63)= x^36 + x^17 + d_in21
////out_22(63)= x^35 + x^16 + d_in22
////out_23(63)= x^34 + x^15 + d_in23
////out_24(63)= x^33 + x^14 + d_in24
////out_25(63)= x^32 + x^13 + d_in25
////out_26(63)= x^31 + x^12 + d_in26
////out_27(63)= x^30 + x^11 + d_in27
////out_28(63)= x^29 + x^10 + d_in28
////out_29(63)= x^28 + x^9 + d_in29
////out_30(63)= x^27 + x^8 + d_in30
////out_31(63)= x^26 + x^7 + d_in31
////out_32(63)= x^25 + x^6 + d_in32
////out_33(63)= x^24 + x^5 + d_in33
////out_34(63)= x^23 + x^4 + d_in34
////out_35(63)= x^22 + x^3 + d_in35
////out_36(63)= x^21 + x^2 + d_in36
////out_37(63)= x^20 + x^1 + d_in37
////out_38(63)= x^19 + x^0 + d_in38
////out_39(63)= x^18 + d_in0 + d_in39
////out_40(63)= x^17 + d_in1 + d_in40
////out_41(63)= x^16 + d_in2 + d_in41
////out_42(63)= x^15 + d_in3 + d_in42
////out_43(63)= x^14 + d_in4 + d_in43
////out_44(63)= x^13 + d_in5 + d_in44
////out_45(63)= x^12 + d_in6 + d_in45
////out_46(63)= x^11 + d_in7 + d_in46
////out_47(63)= x^10 + d_in8 + d_in47
////out_48(63)= x^9 + d_in9 + d_in48
////out_49(63)= x^8 + d_in10 + d_in49
////out_50(63)= x^7 + d_in11 + d_in50
////out_51(63)= x^6 + d_in12 + d_in51
////out_52(63)= x^5 + d_in13 + d_in52
////out_53(63)= x^4 + d_in14 + d_in53
////out_54(63)= x^3 + d_in15 + d_in54
////out_55(63)= x^2 + d_in16 + d_in55
////out_56(63)= x^1 + d_in17 + d_in56
////out_57(63)= x^0 + d_in18 + d_in57
////out_58(63)= d_in0 + d_in19 + d_in58
////out_59(63)= d_in1 + d_in20 + d_in59
////out_60(63)= d_in2 + d_in21 + d_in60
////out_61(63)= d_in3 + d_in22 + d_in61
////out_62(63)= d_in4 + d_in23 + d_in62
////out_63(63)= d_in5 + d_in24 + d_in63
//----------------------------------------------
