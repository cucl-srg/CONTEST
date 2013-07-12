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
// Comma detection unit performs frame boundary detection and alignment.
// Current configuration requires four consecutive ordered sets to lock
// the system(parameterizable).
// This module adopts the locking technique proposed in xilinx xapp581 application.
//////////////////////////////////////////////////////////////////////////////////
module comma_detect
#(
	parameter PCOMMA_10B_VALUE = 10'b0011111010,
	parameter MCOMMA_10B_VALUE = 10'b1100000101,
	parameter COMMA_10B_MASK = 10'b1111111000,
	parameter DATA_5_6_PM  = 10'b1010010110,
	parameter DATA_16_2_M = 10'b0110110101,
	parameter DATA_16_2_P = 10'b1001000101
)
(
	input wire rst,
	input wire clk,
	input wire [19:0] din,
	input wire din_en,
	 
	output wire comma_detected,
	output reg align_acquired,
	output wire [1:0] fsm_state,
	output wire [19:0] aligned_data
);
/*
function integer log2;
	input integer n;
	begin
		log2 = 0;
		while(2**log2 < n) begin
			log2=log2+1;
		end
	end
endfunction
*/

//localparam CNTR_WIDTH = log2(OSN_TO_LOCK);

// fsm
localparam 	INIT_STATE 	= 2'b00,
 	 	LOCKING_STATE = 2'b01,
		ALIGN_STATE   = 2'b10;


////////////////////////////////////////////////////////////////////////
 // masked comma characters //
 wire [9:0] PCOMMA_10B_MASKED;
 wire [9:0] MCOMMA_10B_MASKED;

 // din storage & din ctrls //
 reg [19:0] data_previous_cycle;
 reg [19:0] data_current_cycle;
 reg dv_previous_cycle;
 reg dv_current_cycle;
 reg align_acquired_i;
 
 // comparing storage positions to the comma masks //
 reg [9:0] c_pos0, c_pos1, c_pos2, c_pos3, c_pos4;
 reg [9:0] c_pos5, c_pos6, c_pos7, c_pos8, c_pos9;
 reg [9:0] c_pos10, c_pos11, c_pos12, c_pos13, c_pos14;
 reg [9:0] c_pos15, c_pos16, c_pos17, c_pos18, c_pos19;
 
 // comparing storage positions of char words //
 reg [9:0] d_pos0, d_pos1, d_pos2, d_pos3, d_pos4;
 reg [9:0] d_pos5, d_pos6, d_pos7, d_pos8, d_pos9;
 reg [9:0] d_pos10, d_pos11, d_pos12, d_pos13, d_pos14;
 reg [9:0] d_pos15, d_pos16, d_pos17, d_pos18, d_pos19;
 
 
 // unified matching vector //
 reg [19:0] match_pos;
 
 // counters used in ordered set detection //
 reg [1:0] count_set0, count_set1, count_set2, count_set3, count_set4;
 reg [1:0] count_set5, count_set6, count_set7, count_set8, count_set9;
 reg [1:0] count_set10, count_set11, count_set12, count_set13, count_set14;
 reg [1:0] count_set15, count_set16, count_set17, count_set18, count_set19;

 // ordered set detected
 wire match_det0, match_det1, match_det2, match_det3, match_det4, match_det5;
 wire match_det6, match_det7, match_det8, match_det9, match_det10, match_det11;
 wire match_det12, match_det13, match_det14, match_det15, match_det16;
 wire match_det17, match_det18, match_det19;
 
 wire comma_detected_i;
 
 // align process //
 reg [19:0] shift_offset;
 reg align_in_progress;

// record locking process //
 wire align_pos0, align_pos1, align_pos2, align_pos3, align_pos4, align_pos5;
 wire align_pos6, align_pos7, align_pos8, align_pos9, align_pos10, align_pos11;
 wire align_pos12, align_pos13, align_pos14, align_pos15, align_pos16; 
 wire align_pos17, align_pos18, align_pos19;
 
 // record locking process //
 wire [19:0] aligning_in_pos;
 wire align_in_progress_w;
 wire loss_sync_state;
 
 // out data & ctrl //
 reg align_done;
 reg [19:0] aligned_data_i;
 
 // fsm
  reg [1:0] cur_state, next_state;
 
 ///////////////////////////////////////////////////////////////////////////
 //----------------------------------------------------------------//
 //-- data storage of two input frames       							  //	
 //----------------------------------------------------------------//
  always @ (posedge clk or posedge rst) begin 
		if (rst) begin
			data_current_cycle       <= 0;
        		data_previous_cycle      <= 0;
		        dv_current_cycle         <= 0;
		        dv_previous_cycle        <= 0;
		end
		else begin
			dv_current_cycle         <= din_en;
         		dv_previous_cycle        <= dv_current_cycle;
			
			if (din_en) 
				data_current_cycle    <= din;
						
			if (dv_current_cycle) 
			        data_previous_cycle   <= data_current_cycle;
         	end
  end
         
 //----------------------------------------------------------------
 //-- Matching unit.
 //----------------------------------------------------------------
 //--
 //--     dv_current_cycle      din_en                
 //--     previous cycle        current cycle    
 //--            /---------//---------/
 //--                   1          2                     
 //--                        =========   0  aligned !
 //--                       =========   <- drop 1 bits
 //--                      =========   <- drop 2 bits
 //--                     =========   <- drop 3 bits
 //--                    =========   <- drop 4 bits
 //--                   =========   <- drop 5 bits
 //--                  =========   <- drop 6 bits
 //--                 =========   <- drop 7 bits
 //--                =========   <- drop 8 bits
 //--               =========   <- drop 9 bits
 //----------------------------------------------------------------
 
 assign PCOMMA_10B_MASKED = PCOMMA_10B_VALUE & COMMA_10B_MASK;
 assign MCOMMA_10B_MASKED = MCOMMA_10B_VALUE & COMMA_10B_MASK;  

 /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 always @ (posedge clk or posedge rst) begin
		if (rst) begin
			//comma match
			c_pos0  <= 0;
			c_pos1  <= 0;
			c_pos2  <= 0;
			c_pos3  <= 0;
			c_pos4  <= 0;
			c_pos5  <= 0;
			c_pos6  <= 0;
			c_pos7  <= 0;
			c_pos8  <= 0;
			c_pos9  <= 0;
			c_pos10 <= 0;
			c_pos11 <= 0;
			c_pos12 <= 0;
			c_pos13 <= 0;
			c_pos14 <= 0;
			c_pos15 <= 0;
			c_pos16 <= 0;
			c_pos17 <= 0;
			c_pos18 <= 0;
			c_pos19 <= 0;
 
			// char match
			d_pos0  <= 0;
			d_pos1  <= 0;
			d_pos2  <= 0;
			d_pos3  <= 0;
			d_pos4  <= 0;
			d_pos5  <= 0;
			d_pos6  <= 0;
			d_pos7  <= 0;
			d_pos8  <= 0;
			d_pos9  <= 0;
			d_pos10 <= 0;
			d_pos11 <= 0;
			d_pos12 <= 0;
			d_pos13 <= 0;
			d_pos14 <= 0;
			d_pos15 <= 0;
			d_pos16 <= 0;
			d_pos17 <= 0;
			d_pos18 <= 0;
			d_pos19 <= 0;
 
		end 
		else begin	
			//// look for comma; contains masked comma symbol	 
			c_pos0[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[19:10]);
			c_pos1[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[18:9]);
			c_pos2[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[17:8]);
			c_pos3[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[16:7]);
			c_pos4[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[15:6]);
			c_pos5[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[14:5]);
			c_pos6[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[13:4]);
			c_pos7[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[12:3]);
			c_pos8[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[11:2]);
			c_pos9[9:0]  <= (COMMA_10B_MASK & data_previous_cycle[10:1]);
			c_pos10[9:0] <= (COMMA_10B_MASK & data_previous_cycle[9:0]);
			c_pos11[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[8:0], data_current_cycle[19]}));
			c_pos12[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[7:0], data_current_cycle[19:18]}));
			c_pos13[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[6:0], data_current_cycle[19:17]}));
			c_pos14[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[5:0], data_current_cycle[19:16]}));
			c_pos15[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[4:0], data_current_cycle[19:15]}));
			c_pos16[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[3:0], data_current_cycle[19:14]}));
			c_pos17[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[2:0], data_current_cycle[19:13]}));
			c_pos18[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[1:0], data_current_cycle[19:12]}));
			c_pos19[9:0] <= (COMMA_10B_MASK & ({data_previous_cycle[0], data_current_cycle[19:11]}));
			 
			 //// char character should follow the comma forming ordered set 
			d_pos0[9:0]  <= data_previous_cycle[9:0];
			d_pos1[9:0]  <= {data_previous_cycle[8:0], data_current_cycle[19]};
			d_pos2[9:0]  <= {data_previous_cycle[7:0], data_current_cycle[19:18]};
			d_pos3[9:0]  <= {data_previous_cycle[6:0], data_current_cycle[19:17]};
			d_pos4[9:0]  <= {data_previous_cycle[5:0], data_current_cycle[19:16]};
			d_pos5[9:0]  <= {data_previous_cycle[4:0], data_current_cycle[19:15]};
			d_pos6[9:0]  <= {data_previous_cycle[3:0], data_current_cycle[19:14]};
			d_pos7[9:0]  <= {data_previous_cycle[2:0], data_current_cycle[19:13]};
			d_pos8[9:0]  <= {data_previous_cycle[1:0], data_current_cycle[19:12]};
			d_pos9[9:0]  <= {data_previous_cycle[0], data_current_cycle[19:11]};
			d_pos10[9:0] <= data_current_cycle[19:10];
			d_pos11[9:0] <= data_current_cycle[18:9];
			d_pos12[9:0] <= data_current_cycle[17:8];
			d_pos13[9:0] <= data_current_cycle[16:7];
			d_pos14[9:0] <= data_current_cycle[15:6];
			d_pos15[9:0] <= data_current_cycle[14:5];
			d_pos16[9:0] <= data_current_cycle[13:4];
			d_pos17[9:0] <= data_current_cycle[12:3];
			d_pos18[9:0] <= data_current_cycle[11:2];
			d_pos19[9:0] <= data_current_cycle[10:1]; 
		end
 end
    
  ///// find consecutive match of comma and data symbols 
 assign match_det0 = (((c_pos0 == MCOMMA_10B_MASKED) || (c_pos0 == PCOMMA_10B_MASKED)) && 
						  ((d_pos0 == DATA_5_6_PM) || (d_pos0 == DATA_16_2_P) || (d_pos0 == DATA_16_2_M))) ? 1'b1 : 1'b0; 
 
 assign match_det1 = (((c_pos1 == MCOMMA_10B_MASKED) || (c_pos1 == PCOMMA_10B_MASKED)) && 
						  ((d_pos1 == DATA_5_6_PM) || (d_pos1 == DATA_16_2_P) || (d_pos1 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det2 = (((c_pos2 == MCOMMA_10B_MASKED) || (c_pos2 == PCOMMA_10B_MASKED)) &&
						  ((d_pos2 == DATA_5_6_PM) || (d_pos2 == DATA_16_2_P) || (d_pos2 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det3 = (((c_pos3 == MCOMMA_10B_MASKED) || (c_pos3 == PCOMMA_10B_MASKED )) &&
						  ((d_pos3 == DATA_5_6_PM) || (d_pos3 == DATA_16_2_P) || (d_pos3 == DATA_16_2_M))) ? 1'b1 : 1'b0;
											  
 assign match_det4 = (((c_pos4 == MCOMMA_10B_MASKED) || (c_pos4 == PCOMMA_10B_MASKED )) &&
						  ((d_pos4 == DATA_5_6_PM) || (d_pos4 == DATA_16_2_P) || (d_pos4 == DATA_16_2_M))) ? 1'b1 : 1'b0;	
 
 assign match_det5 = (((c_pos5 == MCOMMA_10B_MASKED) || (c_pos5 == PCOMMA_10B_MASKED )) &&
						  ((d_pos5 == DATA_5_6_PM) || (d_pos5 == DATA_16_2_P) || (d_pos5 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det6 = (((c_pos6 == MCOMMA_10B_MASKED) || (c_pos6 == PCOMMA_10B_MASKED )) &&
						  ((d_pos6 == DATA_5_6_PM) || (d_pos6 == DATA_16_2_P) || (d_pos6 == DATA_16_2_M))) ? 1'b1 : 1'b0;
 	
 assign match_det7 = (((c_pos7 == MCOMMA_10B_MASKED) || (c_pos7 == PCOMMA_10B_MASKED )) &&
						  ((d_pos7 == DATA_5_6_PM) || (d_pos7 == DATA_16_2_P) || (d_pos7 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det8 = (((c_pos8 == MCOMMA_10B_MASKED) || (c_pos8 == PCOMMA_10B_MASKED )) &&
	    				  ((d_pos8 == DATA_5_6_PM) || (d_pos8 == DATA_16_2_P) || (d_pos8 == DATA_16_2_M))) ? 1'b1 : 1'b0;
						  
 assign match_det9 = (((c_pos9 == MCOMMA_10B_MASKED) || (c_pos9 == PCOMMA_10B_MASKED )) &&
	    				  ((d_pos9 == DATA_5_6_PM) || (d_pos9 == DATA_16_2_P) || (d_pos9 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det10 = (((c_pos10 == MCOMMA_10B_MASKED) || (c_pos10 == PCOMMA_10B_MASKED )) &&
	    				   ((d_pos10 == DATA_5_6_PM) || (d_pos10 == DATA_16_2_P) || (d_pos10 == DATA_16_2_M))) ? 1'b1 : 1'b0;
 
 assign match_det11 = (((c_pos11 == MCOMMA_10B_MASKED) || (c_pos11 == PCOMMA_10B_MASKED )) &&
	    				   ((d_pos11 == DATA_5_6_PM) || (d_pos11 == DATA_16_2_P) || (d_pos11 == DATA_16_2_M))) ? 1'b1 : 1'b0; 
							
 assign match_det12 = (((c_pos12 == MCOMMA_10B_MASKED) || (c_pos12 == PCOMMA_10B_MASKED )) &&
							((d_pos12 == DATA_5_6_PM) || (d_pos12 == DATA_16_2_P) || (d_pos12 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det13 = (((c_pos13 == MCOMMA_10B_MASKED) || (c_pos13 == PCOMMA_10B_MASKED )) &&
							((d_pos13 == DATA_5_6_PM) || (d_pos13 == DATA_16_2_P) || (d_pos13 == DATA_16_2_M))) ? 1'b1 : 1'b0;

 assign match_det14 = (((c_pos14 == MCOMMA_10B_MASKED) || (c_pos14 == PCOMMA_10B_MASKED )) &&
							((d_pos14 == DATA_5_6_PM) || (d_pos14 == DATA_16_2_P) || (d_pos14 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							
 assign match_det15 = (((c_pos15 == MCOMMA_10B_MASKED) || (c_pos15 == PCOMMA_10B_MASKED )) &&
							((d_pos15 == DATA_5_6_PM) || (d_pos15 == DATA_16_2_P) || (d_pos15 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							
 assign match_det16 = (((c_pos16 == MCOMMA_10B_MASKED) || (c_pos16 == PCOMMA_10B_MASKED )) &&
							((d_pos16 == DATA_5_6_PM) || (d_pos16 == DATA_16_2_P) || (d_pos16 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							
 assign match_det17 = (((c_pos17 == MCOMMA_10B_MASKED) || (c_pos17 == PCOMMA_10B_MASKED )) &&
							((d_pos17 == DATA_5_6_PM) || (d_pos17 == DATA_16_2_P) || (d_pos17 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							
 assign match_det18 = (((c_pos18 == MCOMMA_10B_MASKED) || (c_pos18 == PCOMMA_10B_MASKED )) &&
							((d_pos18 == DATA_5_6_PM) || (d_pos18 == DATA_16_2_P) || (d_pos18 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							
 assign match_det19 = (((c_pos19 == MCOMMA_10B_MASKED) || (c_pos19 == PCOMMA_10B_MASKED )) &&
							((d_pos19 == DATA_5_6_PM) || (d_pos19 == DATA_16_2_P) || (d_pos19 == DATA_16_2_M))) ? 1'b1 : 1'b0;
							

  //// Match position of a detected ordered set.
  always @ (posedge clk or posedge rst) begin 
		if(rst) begin
			match_pos  <= 0;
		end
		else begin
			if (dv_previous_cycle) begin				
					if (match_det0) match_pos[0] <= 1'b1;
					else match_pos[0] <= 1'b0;

					if (match_det1) match_pos[1] <= 1'b1;	
					else match_pos[1] <= 1'b0;				
				
					if (match_det2)  match_pos[2] <= 1'b1;	
					else match_pos[2] <= 1'b0;
				
					if (match_det3) match_pos[3] <= 1'b1;
					else match_pos[3] <= 1'b0;
					
					if (match_det4) match_pos[4] <= 1'b1; 				
					else	match_pos[4] <= 1'b0;
							
					if (match_det5) match_pos[5] <= 1'b1;
					else match_pos[5] <= 1'b0;

					if (match_det6) match_pos[6] <= 1'b1;
					else match_pos[6] <= 1'b0;
				
					if (match_det7) match_pos[7] <= 1'b1;
					else match_pos[7] <= 1'b0;

					if (match_det8) match_pos[8] <= 1'b1;
					else match_pos[8] <= 1'b0;									
					
					if (match_det9) match_pos[9] <= 1'b1;
					else match_pos[9] <= 1'b0;

					if (match_det10) match_pos[10] <= 1'b1;
					else match_pos[10] <= 1'b0;								
					
					if (match_det11) match_pos[11] <= 1'b1;
					else match_pos[11] <= 1'b0;
				
					if (match_det12) match_pos[12] <= 1'b1;
					else match_pos[12] <= 1'b0;

					if (match_det13) match_pos[13] <= 1'b1;
					else match_pos[13] <= 1'b0;									
					
					if (match_det14) match_pos[14] <= 1'b1;								
					else match_pos[14] <= 1'b0;	
				
					if (match_det15) match_pos[15] <= 1'b1;
					else match_pos[15] <= 1'b0;
				
					if (match_det16) match_pos[16] <= 1'b1;				
					else match_pos[16] <= 1'b0;
				
					if (match_det17) match_pos[17] <= 1'b1;
					else match_pos[17] <= 1'b0;
												
					if (match_det18) match_pos[18] <= 1'b1;					
					else match_pos[18] <= 1'b0;

					if (match_det19) match_pos[19] <= 1'b1;					
					else match_pos[19] <= 1'b0;										
			end
		end
	end	
 
 ///// Detected if at least one match 
 assign comma_detected_i = (|match_pos[19:0]);

 ///// Counting number of ordered sets at every position
 always @ (posedge clk or posedge rst) begin 
	if(rst) begin
		count_set0	<= 0;
		count_set1	<= 0;
		count_set2	<= 0;
		count_set3	<= 0;
		count_set4	<= 0;
		count_set5	<= 0; 
		count_set6	<= 0; 
		count_set7	<= 0;
		count_set8	<= 0;
		count_set9	<= 0;
		count_set10	<= 0;
		count_set11	<= 0;
		count_set12 	<= 0;
		count_set13 	<= 0;
		count_set14 	<= 0;
		count_set15	<= 0;
		count_set16	<= 0;
		count_set17	<= 0;
		count_set18	<= 0;
		count_set19	<= 0;
	end
	else begin
		if (align_acquired_i == 1'b0) begin
			if (match_pos[0]) count_set0 <= count_set0 + 1'b1;
			else count_set0 <= count_set0;
			
			if (match_pos[1]) count_set1 <= count_set1 + 1'b1;
			else count_set1 <= count_set1;	
			
			if (match_pos[2]) count_set2 <= count_set2 + 1'b1;
			else count_set2 <= count_set2;	
			
			if (match_pos[3]) count_set3 <= count_set3 + 1'b1;
			else count_set3 <= count_set3;

			if (match_pos[4]) count_set4 <= count_set4 + 1'b1;
			else count_set4 <= count_set4;
			
			if (match_pos[5]) count_set5 <= count_set5 + 1'b1;
			else count_set5 <= count_set5;
			
			if (match_pos[6]) count_set6 <= count_set6 + 1'b1;
			else count_set6 <= count_set6;
						
			if (match_pos[7]) count_set7 <= count_set7 + 1'b1;
			else count_set7 <= count_set7;
			
			if (match_pos[8]) count_set8 <= count_set8 + 1'b1;
			else count_set8 <= count_set8;
			
			if (match_pos[9]) count_set9 <= count_set9 + 1'b1;
			else count_set9 <= count_set9;
		
			if (match_pos[10]) count_set10 <= count_set10 + 1'b1;
			else count_set10 <= count_set10;
			
			if (match_pos[11]) count_set11 <= count_set11 + 1'b1;
			else count_set11 <= count_set11;
	
			if (match_pos[12]) count_set12 <= count_set12 + 1'b1;
			else count_set12 <= count_set12;
			
			if (match_pos[13]) count_set13 <= count_set13 + 1'b1;
			else count_set13 <= count_set13;
			
			if (match_pos[14]) count_set14 <= count_set14 + 1'b1;
			else count_set14 <= count_set14;
			
			if (match_pos[15]) count_set15 <= count_set15 + 1'b1;
			else count_set15 <= count_set15;
			
			if (match_pos[16]) count_set16 <= count_set16 + 1'b1;
			else count_set16 <= count_set16;
	
			if (match_pos[17]) count_set17 <= count_set17 + 1'b1;
			else count_set17 <= count_set17;
			
			if (match_pos[18]) count_set18 <= count_set18 + 1'b1;
			else count_set18 <= count_set18;
			
			if (match_pos[19]) count_set19 <= count_set19 + 1'b1;
			else count_set19 <= count_set19;
		end
		else begin	
			count_set0	<= 0;
			count_set1	<= 0;
			count_set2	<= 0;
			count_set3	<= 0;
			count_set4	<= 0;
			count_set5	<= 0; 
			count_set6	<= 0; 
			count_set7	<= 0;
			count_set8	<= 0;
			count_set9	<= 0;
			count_set10	<= 0;
			count_set11	<= 0;
			count_set12 	<= 0;
			count_set13 	<= 0;
			count_set14 	<= 0;
			count_set15	<= 0;
			count_set16	<= 0;
			count_set17	<= 0;
			count_set18	<= 0;
			count_set19	<= 0;
		end	
								
	end	
 end
 
 //----------------------------------------------------------------------------------------------------//
 //-- Identify when the aligning process starts 
 //----------------------------------------------------------------------------------------------------//
 // counter != (2'b00 | 2'b11) -> ^counter 
 assign align_pos0 = (count_set0[1] ^ count_set0[0]) ? 1'b1 : 1'b0;
 assign align_pos1 = (count_set1[1] ^ count_set1[0]) ? 1'b1 : 1'b0;  	  	
 assign align_pos2 = (count_set2[1] ^ count_set2[0]) ? 1'b1 : 1'b0;  	
 assign align_pos3 = (count_set3[1] ^ count_set3[0]) ? 1'b1 : 1'b0;  	
 assign align_pos4 = (count_set4[1] ^ count_set4[0]) ? 1'b1 : 1'b0;  	
 assign align_pos5 = (count_set5[1] ^ count_set5[0]) ? 1'b1 : 1'b0;  	
 assign align_pos6 = (count_set6[1] ^ count_set6[0]) ? 1'b1 : 1'b0;  	
 assign align_pos7 = (count_set7[1] ^ count_set7[0]) ? 1'b1 : 1'b0;  	 
 assign align_pos8 = (count_set8[1] ^ count_set8[0]) ? 1'b1 : 1'b0;  	
 assign align_pos9 = (count_set9[1] ^ count_set9[0]) ? 1'b1 : 1'b0;  	
 assign align_pos10 = (count_set10[1] ^ count_set10[0]) ? 1'b1 : 1'b0;
 assign align_pos11 = (count_set11[1] ^ count_set11[0]) ? 1'b1 : 1'b0;  	  	
 assign align_pos12 = (count_set12[1] ^ count_set12[0]) ? 1'b1 : 1'b0;  	
 assign align_pos13 = (count_set13[1] ^ count_set13[0]) ? 1'b1 : 1'b0;  	
 assign align_pos14 = (count_set14[1] ^ count_set14[0]) ? 1'b1 : 1'b0;  	
 assign align_pos15 = (count_set15[1] ^ count_set15[0]) ? 1'b1 : 1'b0;  	
 assign align_pos16 = (count_set16[1] ^ count_set16[0]) ? 1'b1 : 1'b0;  	
 assign align_pos17 = (count_set17[1] ^ count_set17[0]) ? 1'b1 : 1'b0;  	 
 assign align_pos18 = (count_set18[1] ^ count_set18[0]) ? 1'b1 : 1'b0;  	
 assign align_pos19 = (count_set19[1] ^ count_set19[0]) ? 1'b1 : 1'b0;

assign align_in_progress_w = (align_pos0 | align_pos1 | align_pos2 | align_pos3 | align_pos4 | align_pos5
			      | align_pos6 | align_pos7 | align_pos8 | align_pos9 | align_pos10 | align_pos11
			      | align_pos12 | align_pos13 | align_pos14 | align_pos15 | align_pos16 | align_pos17
			      | align_pos18 | align_pos19);	
 
 //----------------------------------------------------------------------------------------------------//
 //-- After seeing 4 detected, non-aligned ordered sets, move to output shifting phase. 
 //----------------------------------------------------------------------------------------------------//
 // counter == 2'b11
  
  always @ (posedge clk or posedge rst) begin
	if(rst) begin
		shift_offset 		<= 'b0;
		align_in_progress 	<= 'b0;		
	end
	else begin
		if (count_set0[1] & count_set0[0]) shift_offset[0] <= 1'b1;
		else if(count_set1[1] & count_set1[0]) shift_offset[1] <= 1'b1;
		else if(count_set2[1] & count_set2[0]) shift_offset[2] <= 1'b1;
		else if(count_set3[1] & count_set3[0]) shift_offset[3] <= 1'b1;
		else if(count_set4[1] & count_set4[0]) shift_offset[4] <= 1'b1;
		else if(count_set5[1] & count_set5[0]) shift_offset[5] <= 1'b1;
		else if(count_set6[1] & count_set6[0]) shift_offset[6] <= 1'b1;		
		else if(count_set7[1] & count_set7[0]) shift_offset[7] <= 1'b1;
		else if(count_set8[1] & count_set8[0]) shift_offset[8] <= 1'b1;
		else if(count_set9[1] & count_set9[0]) shift_offset[9] <= 1'b1;
		else if(count_set10[1] & count_set10[0]) shift_offset[10] <= 1'b1;
		else if(count_set11[1] & count_set11[0]) shift_offset[11] <= 1'b1;
		else if(count_set12[1] & count_set12[0]) shift_offset[12] <= 1'b1;
		else if(count_set13[1] & count_set13[0]) shift_offset[13] <= 1'b1;
		else if(count_set14[1] & count_set14[0]) shift_offset[14] <= 1'b1;
		else if(count_set15[1] & count_set15[0]) shift_offset[15] <= 1'b1;
		else if(count_set16[1] & count_set16[0]) shift_offset[16] <= 1'b1;
		else if(count_set17[1] & count_set17[0]) shift_offset[17] <= 1'b1;
		else if(count_set18[1] & count_set18[0]) shift_offset[18] <= 1'b1;
		else if(count_set19[1] & count_set19[0]) shift_offset[19] <= 1'b1;

		align_in_progress <= align_in_progress_w;	
	end
 end
 
 //----------------------------------------------------------------------------------------------------//
 //-- Start position is evaluated; Latch data out appropriately
 //----------------------------------------------------------------------------------------------------//
 
 always @ (posedge clk or posedge rst) begin 
	if(rst) begin
		aligned_data_i			<= 0;		
		align_done			<= 0;
	end
	else begin	
		if (shift_offset[0]) begin
			 aligned_data_i <= data_previous_cycle[19:0]; 
			 align_done <= 1'b1; 
		end
		else if(shift_offset[1]) begin
			 aligned_data_i <= {data_previous_cycle[18:0], data_current_cycle[19]}; 
			 align_done <= 1'b1;
		end
		else if(shift_offset[2]) begin
			 aligned_data_i <= {data_previous_cycle[17:0], data_current_cycle[19:18]};
			 align_done <= 1'b1;
		end
		else if(shift_offset[3]) begin
			aligned_data_i <= {data_previous_cycle[16:0], data_current_cycle[19:17]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[4]) begin
			aligned_data_i <= {data_previous_cycle[15:0], data_current_cycle[19:16]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[5]) begin
			aligned_data_i <= {data_previous_cycle[14:0], data_current_cycle[19:15]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[6]) begin
			aligned_data_i <= {data_previous_cycle[13:0], data_current_cycle[19:14]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[7]) begin
			aligned_data_i <= {data_previous_cycle[12:0], data_current_cycle[19:13]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[8]) begin
			aligned_data_i <= {data_previous_cycle[11:0], data_current_cycle[19:12]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[9]) begin
			aligned_data_i <= {data_previous_cycle[10:0], data_current_cycle[19:11]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[10]) begin
			aligned_data_i <= {data_previous_cycle[9:0], data_current_cycle[19:10]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[11]) begin
			aligned_data_i <= {data_previous_cycle[8:0], data_current_cycle[19:9]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[12]) begin
			aligned_data_i <= {data_previous_cycle[7:0], data_current_cycle[19:8]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[13]) begin
			aligned_data_i <= {data_previous_cycle[6:0], data_current_cycle[19:7]};
			align_done <= 1'b1;
		end 
		else if(shift_offset[14]) begin
			aligned_data_i <= {data_previous_cycle[5:0], data_current_cycle[19:6]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[15]) begin
			aligned_data_i <= {data_previous_cycle[4:0], data_current_cycle[19:5]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[16]) begin
			aligned_data_i <= {data_previous_cycle[3:0], data_current_cycle[19:4]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[17]) begin
			aligned_data_i <= {data_previous_cycle[2:0], data_current_cycle[19:3]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[18]) begin
			aligned_data_i <= {data_previous_cycle[1:0], data_current_cycle[19:2]}; 
			align_done <= 1'b1;
		end
		else if(shift_offset[19]) begin
			aligned_data_i <= {data_previous_cycle[0], data_current_cycle[19:1]}; 
			align_done <= 1'b1;
		end		
		else begin
			aligned_data_i <= 'b0;
			align_done <= 1'b0;
		end

	end
 end
 
 //-----------------------------------------------------------------------------------//
 //-- Generate alignment acquired signal
 //-----------------------------------------------------------------------------------//
  
  always @ (posedge clk or posedge rst) begin
		if (rst) begin
			align_acquired   <= 1'b0;
			align_acquired_i <= 1'b0;
		end
		else begin
			align_acquired  <= align_acquired_i;
			if (align_done) begin	
				align_acquired_i <= 1'b1;				
			end
			else begin
				align_acquired_i <= 1'b0;
			end	
		end
  end
 
   assign loss_sync_state = ~((align_acquired_i == 1'b1) || (align_in_progress == 1'b1));
 
 //----------------------------------------------------------------------------------//
 //-- Help the other modules to identify the current frame locking stage
 //----------------------------------------------------------------------------------//
 
 // fsm comb
 always @(*) begin
	if (rst) begin
		next_state = INIT_STATE;
	end
	else begin
		next_state = cur_state;
		case (cur_state)
			INIT_STATE: begin
				// 0x00
				if (loss_sync_state) next_state = INIT_STATE;
				else next_state = LOCKING_STATE;
			end
			 LOCKING_STATE: begin
				// 0x01
				if (align_acquired_i) next_state = ALIGN_STATE; 
				else next_state = LOCKING_STATE;	      
			end
			ALIGN_STATE: begin
				// 0x10
				if (loss_sync_state) next_state = INIT_STATE;
				else next_state = ALIGN_STATE;
			end
		
			default: next_state = INIT_STATE;
		endcase
	end
 end
 
 // fsm seq
 always @(posedge clk or posedge rst) begin
	if (rst) cur_state <= INIT_STATE;
	else  cur_state <= next_state;
 end

 //----------------------------------------------------------------------------------//
 //-- Final output assignments
 //----------------------------------------------------------------------------------//
 assign comma_detected  = comma_detected_i;
 assign aligned_data = aligned_data_i;
 assign fsm_state = cur_state; 
 
 
endmodule
