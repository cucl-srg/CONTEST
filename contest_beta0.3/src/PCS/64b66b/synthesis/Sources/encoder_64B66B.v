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
// Description: 64b66b encoding performs transformation of XGMII format into 10GBASE-R format.
// XGMII input sequences are: 64-bit data sequence and 8-bit control sequence (received form XGMII interface).
// 64-bit sequence is split into 8 octets; these blocks are represented in a specific format - clause 49.2.4.4
// data is not encoded (01 synch header is added), it is directly sent to scrambler. On the contrary control or 
// mixed control/data sequences are formatted from xgmii representation to the 10GBASE-R format. 
// Frame format is shown below.
//	[sync(01)]/[data(8 octets)]
//	[sync(10)]/[type(8bit)]/[data/O fields/C fields] - 15 different combinations
// 
//////////////////////////////////////////////////////////////////////////////////
module encoder_64B66B(
 input wire reset,
 input wire clock,
 input wire [63:0] xgmii_in_txd,
 input wire [7:0] xgmii_in_txc,
 output reg [65:0] out_txd, 
 output reg out_invalid
);
 	
 // xgmii control blocks for each octet
 //--------------------------------------------------------------------------------------
 // data and control flags, used to distinguish data seq from control seq
 reg octet0_data;
 reg octet0_ctrl;
 reg octet1_data;
 reg octet1_ctrl;
 reg octet2_data;
 reg octet2_ctrl;
 reg octet3_data;
 reg octet3_ctrl;
 reg octet4_data;
 reg octet4_ctrl;
 reg octet5_data;
 reg octet5_ctrl;
 reg octet6_data;
 reg octet6_ctrl;
 reg octet7_data;
 reg octet7_ctrl;
 
 //---------------------------------------------------------------------------------------
 // used for control sequences only 
 // octet 0 flags
 // idle, start, term., error, Seq. order_set, res0, res1,
 // res2, res3, res4, res5, Sign. order_set 
 reg [11:0] octet0_ctrl_flags;
   
 // octet 4 flags
 // idle, start, term., Seq. order_set, res0, res1,
 // res2, res3, res4, res5, Sign. order_set 
 reg [10:0] octet4_ctrl_flags;
 
 // octet 1-3, 5-7 flags
 // idle, term., res0, res1, res2, res3, res4, res5
 reg [7:0] octet1_ctrl_flags;
 reg [7:0] octet2_ctrl_flags;
 reg [7:0] octet3_ctrl_flags;
 reg [7:0] octet5_ctrl_flags;
 reg [7:0] octet6_ctrl_flags;
 reg [7:0] octet7_ctrl_flags;
  
 // 64-bit xgmii sequence is split into 8 blocks
 // -------------------------------------------------------------------------------------
 reg [63:0] xgmii_data_regs;	// data in xgmii format
 
 // intermediate registers with data as is, 8 logical lanes
 wire [7:0] xgmii_data_lane0;	
 wire [7:0] xgmii_data_lane1;
 wire [7:0] xgmii_data_lane2;
 wire [7:0] xgmii_data_lane3;
 wire [7:0] xgmii_data_lane4;
 wire [7:0] xgmii_data_lane5;
 wire [7:0] xgmii_data_lane6;
 wire [7:0] xgmii_data_lane7; 
 
 // 10GBASE-R encoding
 // ----------------------------------------------------------------------------------------
 reg [63:0] GBaseR_data_regs;
 reg [6:0] GBaseR_C0; //control codes C0-C7 listed in Table 49-1	
 reg [6:0] GBaseR_C1;
 reg [6:0] GBaseR_C2;
 reg [6:0] GBaseR_C3;
 reg [6:0] GBaseR_C4;
 reg [6:0] GBaseR_C5;
 reg [6:0] GBaseR_C6;
 reg [6:0] GBaseR_C7;
 reg [3:0] GBaseR_O0; // ordered sets O0 and O4
 reg [3:0] GBaseR_O4;
  
 // output format
 //[2b(sync header)/8b(block type field)/56b(mixture of control and data)]
 //----------------------------------------------------------------------------------------
 reg [1:0] out_sync_header;			// sync header
 reg [7:0] out_type_field;				// blk type field
 reg [55:0] out_data;					// data/control
 
 wire [65:0] mult_out_txd;				// puts data in a specified (above) format
 // flags of all possible type field blocks - Figure 49-7
 // ----------------------------------------------------------------------------------------
 // [14] - 0x1E, [13] - 0x2D, [12] - 0x33, [11] - 0x66 , [10] - 0x55, 
 // [9] - 0x78, [8] - 0x4B, [7] - 0x87, [6] - 0x99, [5] - 0xAA, 
 // [4] - 0xB4, [3] - 0xCC, [2] - 0xD2, [1] - 0xE1, [0] - 0xFF
 wire [14:0] type_control;
 reg [14:0] type_control_reg;
 
 // if sequence is data
 wire type_data;
 reg type_data_reg;
 // check for ctrl bits
 wire type_prob_ctrl;
  
 // output frame type
 reg [2:0] frame_type_reg;
 wire [2:0] frame_type;

 parameter [2:0] ctrl_frame = 3'b001, 
					  start_frame = 3'b010,
					  terminate_frame = 3'b011,
					  data_frame = 3'b100,
					  illegal_frame = 3'b101;

 
 //----------------------------------------------------------------------------------------
 // First we determine whether incoming 64-bit sequence is only data;
 // we also distribute the data among 8 lines
 
 assign xgmii_data_lane0 = xgmii_in_txd[7:0];
 assign xgmii_data_lane1 = xgmii_in_txd[15:8];
 assign xgmii_data_lane2 = xgmii_in_txd[23:16];
 assign xgmii_data_lane3 = xgmii_in_txd[31:24];
 assign xgmii_data_lane4 = xgmii_in_txd[39:32];
 assign xgmii_data_lane5 = xgmii_in_txd[47:40];
 assign xgmii_data_lane6 = xgmii_in_txd[55:48];
 assign xgmii_data_lane7 = xgmii_in_txd[63:56];
 
 // ----------------------------------------------------------------------------------------
 
 
 // keep the complete sequence in registers in case input sequence is data
	always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			xgmii_data_regs <= {64{1'b0}};					
		end
		else begin
			xgmii_data_regs <= xgmii_in_txd;						
		end
	end
	
	// another set of registers to signify control/data seq. in each lane
	// lane 0
	always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet0_data <= 1'b0;
			octet0_ctrl <= 1'b0;
		end 
		else begin					
			octet0_data <= ~(xgmii_in_txc[0]);
			octet0_ctrl <= xgmii_in_txc[0];
		end	
	end

	// lane 1
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet1_data <= 1'b0;
			octet1_ctrl <= 1'b0;
		end 
		else begin					
			octet1_data <= ~(xgmii_in_txc[1]);
			octet1_ctrl <= xgmii_in_txc[1];
		end	
	end
	
	// lane 2
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet2_data <= 1'b0;
			octet2_ctrl <= 1'b0;
		end 
		else begin
			octet2_data <= ~(xgmii_in_txc[2]);
			octet2_ctrl <= xgmii_in_txc[2];
		end	
	end	
	
	// lane 3
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet3_data <= 1'b0;
			octet3_ctrl <= 1'b0;
		end 
		else begin
			octet3_data <= ~(xgmii_in_txc[3]);
			octet3_ctrl <= xgmii_in_txc[3];
		end	
	end	
			
	// lane 4
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet4_data <= 1'b0;
			octet4_ctrl <= 1'b0;
		end 
		else begin
			octet4_data <= ~(xgmii_in_txc[4]);
			octet4_ctrl <= xgmii_in_txc[4];
		end	
	end	
	
	// lane 5
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet5_data <= 1'b0;
			octet5_ctrl <= 1'b0;
		end 
		else begin
			octet5_data <= ~(xgmii_in_txc[5]);
			octet5_ctrl <= xgmii_in_txc[5];
		end	
	end	
	
	// lane 6
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet6_data <= 1'b0;
			octet6_ctrl <= 1'b0;
		end 
		else begin					
			octet6_data <= ~(xgmii_in_txc[6]);
			octet6_ctrl <= xgmii_in_txc[6];
		end	
	end
	
	// lane 7
   always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			octet7_data <= 1'b0;
			octet7_ctrl <= 1'b0;
		end 
		else begin
					
			octet7_data <= ~(xgmii_in_txc[7]);
			octet7_ctrl <= xgmii_in_txc[7];
		end	
	end

 //--------------------------------------------------------------------------
 // data type - only remaining 56 bits are checked
 assign type_data = octet0_data & octet1_data & octet2_data & octet3_data & octet4_data & octet5_data & octet6_data & octet7_data;

// sequence can look like a control type, but it might not
// conform to block type codes specified in the standard.
// Check whether we have at least one non zero bit, e.g. it is not data
 assign type_prob_ctrl = octet0_ctrl | octet1_ctrl | octet2_ctrl | octet3_ctrl | octet4_ctrl | octet5_ctrl | octet6_ctrl | octet0_ctrl ;

 // ---------------------------------------------------------------------------------------
 // here we match the control words arrived from XGMII interface to the known XGMII codes
 // represented in Table 49-1 and given in xgmii_in_txc.
 //----------------------------------------------------------------------------------------
 
 // octet 0 - Table 49-1, column 3, 12 characters
   always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet0_ctrl_flags <= {12{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet0_ctrl_flags[0] <= ~(xgmii_data_lane0[7]) & ~(xgmii_data_lane0[6]) & ~(xgmii_data_lane0[5]) & ~(xgmii_data_lane0[4]) &
											~(xgmii_data_lane0[3]) & xgmii_data_lane0[2] & xgmii_data_lane0[1] & xgmii_data_lane0[0] & 
											xgmii_in_txc[0];
											
			//1. start character /S/ - 0xfb, 8'b1111_1011										
			octet0_ctrl_flags[1] <= xgmii_data_lane0[7] & xgmii_data_lane0[6] & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & ~(xgmii_data_lane0[2]) & xgmii_data_lane0[1] & xgmii_data_lane0[0] & 
											xgmii_in_txc[0];
			
			//2. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet0_ctrl_flags[2] <= xgmii_data_lane0[7] & xgmii_data_lane0[6] & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & xgmii_data_lane0[0] & 
											xgmii_in_txc[0];
			
			//3. error character /E/ - 0xfe, 8'b1111_1110
			octet0_ctrl_flags[3] <= xgmii_data_lane0[7] & xgmii_data_lane0[6] & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & xgmii_data_lane0[1] & ~(xgmii_data_lane0[0]) & 
											xgmii_in_txc[0];
											
			//4. seq ordered set character /Q/ - 0x9c, 8'b1001_1100										
			octet0_ctrl_flags[4] <= xgmii_data_lane0[7] & ~(xgmii_data_lane0[6]) & ~(xgmii_data_lane0[5]) & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) & 
											xgmii_in_txc[0];
			
			//5. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet0_ctrl_flags[5] <= ~(xgmii_data_lane0[7]) & ~(xgmii_data_lane0[6]) & ~(xgmii_data_lane0[5]) & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];
											
			//6. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet0_ctrl_flags[6] <= ~(xgmii_data_lane0[7]) & ~(xgmii_data_lane0[6]) & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];								
											
			//7. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet0_ctrl_flags[7] <= ~(xgmii_data_lane0[7]) & xgmii_data_lane0[6] & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];								
											
			//8. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet0_ctrl_flags[8] <= xgmii_data_lane0[7] & ~(xgmii_data_lane0[6]) & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];								
			
			//9. reserved4 character    - 0xdc, 8'b1101_1100										
			octet0_ctrl_flags[9] <= xgmii_data_lane0[7] & xgmii_data_lane0[6] & ~(xgmii_data_lane0[5]) & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];									
											
			//10. reserved5 character    - 0xf7, 8'b1111_0111										
			octet0_ctrl_flags[10] <= xgmii_data_lane0[7] & xgmii_data_lane0[6] & xgmii_data_lane0[5] & xgmii_data_lane0[4] &
											~(xgmii_data_lane0[3]) & xgmii_data_lane0[2] & xgmii_data_lane0[1] & xgmii_data_lane0[0] &   
											xgmii_in_txc[0];									
			
			//11. signal ordered set character /Fsig/ - 0x5c, 8'b0101_1100										
			octet0_ctrl_flags[11] <= ~(xgmii_data_lane0[7]) & xgmii_data_lane0[6] & ~(xgmii_data_lane0[5]) & xgmii_data_lane0[4] &
											xgmii_data_lane0[3] & xgmii_data_lane0[2] & ~(xgmii_data_lane0[1]) & ~(xgmii_data_lane0[0]) &   
											xgmii_in_txc[0];	
				
	end
	

	// octet 1 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet1_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet1_ctrl_flags[0] <= ~(xgmii_data_lane1[7]) & ~(xgmii_data_lane1[6]) & ~(xgmii_data_lane1[5]) & ~(xgmii_data_lane1[4]) &
											~(xgmii_data_lane1[3]) & xgmii_data_lane1[2] & xgmii_data_lane1[1] & xgmii_data_lane1[0] & 
											xgmii_in_txc[1];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet1_ctrl_flags[1] <= xgmii_data_lane1[7] & xgmii_data_lane1[6] & xgmii_data_lane1[5] & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & xgmii_data_lane1[0] & 
											xgmii_in_txc[1];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet1_ctrl_flags[2] <= ~(xgmii_data_lane1[7]) & ~(xgmii_data_lane1[6]) & ~(xgmii_data_lane1[5]) & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & ~(xgmii_data_lane1[0]) &   
											xgmii_in_txc[1];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet1_ctrl_flags[3] <= ~(xgmii_data_lane1[7]) & ~(xgmii_data_lane1[6]) & xgmii_data_lane1[5] & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & ~(xgmii_data_lane1[0]) &   
											xgmii_in_txc[1];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet1_ctrl_flags[4] <= ~(xgmii_data_lane1[7]) & xgmii_data_lane1[6] & xgmii_data_lane1[5] & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & ~(xgmii_data_lane1[0]) &   
											xgmii_in_txc[1];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet1_ctrl_flags[5] <= xgmii_data_lane1[7] & ~(xgmii_data_lane1[6]) & xgmii_data_lane1[5] & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & ~(xgmii_data_lane1[0]) &   
											xgmii_in_txc[1];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet1_ctrl_flags[6] <= xgmii_data_lane1[7] & xgmii_data_lane1[6] & ~(xgmii_data_lane1[5]) & xgmii_data_lane1[4] &
											xgmii_data_lane1[3] & xgmii_data_lane1[2] & ~(xgmii_data_lane1[1]) & ~(xgmii_data_lane1[0]) &   
											xgmii_in_txc[1];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet1_ctrl_flags[7] <= xgmii_data_lane1[7] & xgmii_data_lane1[6] & xgmii_data_lane1[5] & xgmii_data_lane1[4] &
											~(xgmii_data_lane1[3]) & xgmii_data_lane1[2] & xgmii_data_lane1[1] & xgmii_data_lane1[0] &   
											xgmii_in_txc[1];									
									
		end
	
	
  // octet 2 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet2_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet2_ctrl_flags[0] <= ~(xgmii_data_lane2[7]) & ~(xgmii_data_lane2[6]) & ~(xgmii_data_lane2[5]) & ~(xgmii_data_lane2[4]) &
											~(xgmii_data_lane2[3]) & xgmii_data_lane2[2] & xgmii_data_lane2[1] & xgmii_data_lane2[0] & 
											xgmii_in_txc[2];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet2_ctrl_flags[1] <= xgmii_data_lane2[7] & xgmii_data_lane2[6] & xgmii_data_lane2[5] & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & xgmii_data_lane2[0] & 
											xgmii_in_txc[2];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet2_ctrl_flags[2] <= ~(xgmii_data_lane2[7]) & ~(xgmii_data_lane2[6]) & ~(xgmii_data_lane2[5]) & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & ~(xgmii_data_lane2[0]) &   
											xgmii_in_txc[2];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet2_ctrl_flags[3] <= ~(xgmii_data_lane2[7]) & ~(xgmii_data_lane2[6]) & xgmii_data_lane2[5] & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & ~(xgmii_data_lane2[0]) &   
											xgmii_in_txc[2];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet2_ctrl_flags[4] <= ~(xgmii_data_lane2[7]) & xgmii_data_lane2[6] & xgmii_data_lane2[5] & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & ~(xgmii_data_lane2[0]) &   
											xgmii_in_txc[2];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet2_ctrl_flags[5] <= xgmii_data_lane2[7] & ~(xgmii_data_lane2[6]) & xgmii_data_lane2[5] & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & ~(xgmii_data_lane2[0]) &   
											xgmii_in_txc[2];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet2_ctrl_flags[6] <= xgmii_data_lane2[7] & xgmii_data_lane2[6] & ~(xgmii_data_lane2[5]) & xgmii_data_lane2[4] &
											xgmii_data_lane2[3] & xgmii_data_lane2[2] & ~(xgmii_data_lane2[1]) & ~(xgmii_data_lane2[0]) &   
											xgmii_in_txc[2];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet2_ctrl_flags[7] <= xgmii_data_lane2[7] & xgmii_data_lane2[6] & xgmii_data_lane2[5] & xgmii_data_lane2[4] &
											~(xgmii_data_lane2[3]) & xgmii_data_lane2[2] & xgmii_data_lane2[1] & xgmii_data_lane2[0] &   
											xgmii_in_txc[2];									
									
	end
		
	// octet 3 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet3_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet3_ctrl_flags[0] <= ~(xgmii_data_lane3[7]) & ~(xgmii_data_lane3[6]) & ~(xgmii_data_lane3[5]) & ~(xgmii_data_lane3[4]) &
											~(xgmii_data_lane3[3]) & xgmii_data_lane3[2] & xgmii_data_lane3[1] & xgmii_data_lane3[0] & 
											xgmii_in_txc[3];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet3_ctrl_flags[1] <= xgmii_data_lane3[7] & xgmii_data_lane3[6] & xgmii_data_lane3[5] & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & xgmii_data_lane3[0] & 
											xgmii_in_txc[3];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet3_ctrl_flags[2] <= ~(xgmii_data_lane3[7]) & ~(xgmii_data_lane3[6]) & ~(xgmii_data_lane3[5]) & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & ~(xgmii_data_lane3[0]) &   
											xgmii_in_txc[3];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet3_ctrl_flags[3] <= ~(xgmii_data_lane3[7]) & ~(xgmii_data_lane3[6]) & xgmii_data_lane3[5] & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & ~(xgmii_data_lane3[0]) &   
											xgmii_in_txc[3];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet3_ctrl_flags[4] <= ~(xgmii_data_lane3[7]) & xgmii_data_lane3[6] & xgmii_data_lane3[5] & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & ~(xgmii_data_lane3[0]) &   
											xgmii_in_txc[3];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet3_ctrl_flags[5] <= xgmii_data_lane3[7] & ~(xgmii_data_lane3[6]) & xgmii_data_lane3[5] & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & ~(xgmii_data_lane3[0]) &   
											xgmii_in_txc[3];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet3_ctrl_flags[6] <= xgmii_data_lane3[7] & xgmii_data_lane3[6] & ~(xgmii_data_lane3[5]) & xgmii_data_lane3[4] &
											xgmii_data_lane3[3] & xgmii_data_lane3[2] & ~(xgmii_data_lane3[1]) & ~(xgmii_data_lane3[0]) &   
											xgmii_in_txc[3];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet3_ctrl_flags[7] <= xgmii_data_lane3[7] & xgmii_data_lane3[6] & xgmii_data_lane3[5] & xgmii_data_lane3[4] &
											~(xgmii_data_lane3[3]) & xgmii_data_lane3[2] & xgmii_data_lane3[1] & xgmii_data_lane3[0] &   
											xgmii_in_txc[3];									
									
		end

		
	// octet 4 - Table 49-1, column 3, 11 characters (no error s.)
   always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet4_ctrl_flags <= {11{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet4_ctrl_flags[0] <= ~(xgmii_data_lane4[7]) & ~(xgmii_data_lane4[6]) & ~(xgmii_data_lane4[5]) & ~(xgmii_data_lane4[4]) &
											~(xgmii_data_lane4[3]) & xgmii_data_lane4[2] & xgmii_data_lane4[1] & xgmii_data_lane4[0] & 
											xgmii_in_txc[4];
											
			//1. start character /S/ - 0xfb, 8'b1111_1011										
			octet4_ctrl_flags[1] <= xgmii_data_lane4[7] & xgmii_data_lane4[6] & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & ~(xgmii_data_lane4[2]) & xgmii_data_lane4[1] & xgmii_data_lane4[0] & 
											xgmii_in_txc[4];
			
			//2. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet4_ctrl_flags[2] <= xgmii_data_lane4[7] & xgmii_data_lane4[6] & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & xgmii_data_lane4[0] & 
											xgmii_in_txc[4];
			
			//3. seq ordered set character /Q/ - 0x9c, 8'b1001_1100										
			octet4_ctrl_flags[3] <= xgmii_data_lane4[7] & ~(xgmii_data_lane4[6]) & ~(xgmii_data_lane4[5]) & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) & 
											xgmii_in_txc[4];
			
			//4. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet4_ctrl_flags[4] <= ~(xgmii_data_lane4[7]) & ~(xgmii_data_lane4[6]) & ~(xgmii_data_lane4[5]) & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];
											
			//5. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet4_ctrl_flags[5] <= ~(xgmii_data_lane4[7]) & ~(xgmii_data_lane4[6]) & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];								
											
			//6. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet4_ctrl_flags[6] <= ~(xgmii_data_lane4[7]) & xgmii_data_lane4[6] & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];								
											
			//7. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet4_ctrl_flags[7] <= xgmii_data_lane4[7] & ~(xgmii_data_lane4[6]) & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];								
			
			//8. reserved4 character    - 0xdc, 8'b1101_1100										
			octet4_ctrl_flags[8] <= xgmii_data_lane4[7] & xgmii_data_lane4[6] & ~(xgmii_data_lane4[5]) & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];									
											
			//9. reserved5 character    - 0xf7, 8'b1111_0111										
			octet4_ctrl_flags[9] <= xgmii_data_lane4[7] & xgmii_data_lane4[6] & xgmii_data_lane4[5] & xgmii_data_lane4[4] &
											~(xgmii_data_lane4[3]) & xgmii_data_lane4[2] & xgmii_data_lane4[1] & xgmii_data_lane4[0] &   
											xgmii_in_txc[4];									
			
			//10. signal ordered set character /Fsig/ - 0x5c, 8'b0101_1100										
			octet4_ctrl_flags[10] <= ~(xgmii_data_lane4[7]) & xgmii_data_lane4[6] & ~(xgmii_data_lane4[5]) & xgmii_data_lane4[4] &
											xgmii_data_lane4[3] & xgmii_data_lane4[2] & ~(xgmii_data_lane4[1]) & ~(xgmii_data_lane4[0]) &   
											xgmii_in_txc[4];	
				
	end
	
	// octet 5 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet5_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet5_ctrl_flags[0] <= ~(xgmii_data_lane5[7]) & ~(xgmii_data_lane5[6]) &~(xgmii_data_lane5[5]) & ~(xgmii_data_lane5[4]) &
											~(xgmii_data_lane5[3]) & xgmii_data_lane5[2] & xgmii_data_lane5[1] & xgmii_data_lane5[0] & 
											xgmii_in_txc[5];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet5_ctrl_flags[1] <= xgmii_data_lane5[7] & xgmii_data_lane5[6] & xgmii_data_lane5[5] & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & xgmii_data_lane5[0] & 
											xgmii_in_txc[5];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet5_ctrl_flags[2] <= ~(xgmii_data_lane5[7]) & ~(xgmii_data_lane5[6]) & ~(xgmii_data_lane5[5]) & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & ~(xgmii_data_lane5[0]) &   
											xgmii_in_txc[5];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet5_ctrl_flags[3] <= ~(xgmii_data_lane5[7]) & ~(xgmii_data_lane5[6]) & xgmii_data_lane5[5] & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & ~(xgmii_data_lane5[0]) &   
											xgmii_in_txc[5];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet5_ctrl_flags[4] <= ~(xgmii_data_lane5[7]) & xgmii_data_lane5[6] & xgmii_data_lane5[5] & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & ~(xgmii_data_lane5[0]) &   
											xgmii_in_txc[5];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet5_ctrl_flags[5] <= xgmii_data_lane5[7] & ~(xgmii_data_lane5[6]) & xgmii_data_lane5[5] & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & ~(xgmii_data_lane5[0]) &   
											xgmii_in_txc[5];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet5_ctrl_flags[6] <= xgmii_data_lane5[7] & xgmii_data_lane5[6] & ~(xgmii_data_lane5[5]) & xgmii_data_lane5[4] &
											xgmii_data_lane5[3] & xgmii_data_lane5[2] & ~(xgmii_data_lane5[1]) & ~(xgmii_data_lane5[0]) &   
											xgmii_in_txc[5];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet5_ctrl_flags[7] <= xgmii_data_lane5[7] & xgmii_data_lane5[6] & xgmii_data_lane5[5] & xgmii_data_lane5[4] &
											~(xgmii_data_lane5[3]) & xgmii_data_lane5[2] & xgmii_data_lane5[1] & xgmii_data_lane5[0] &   
											xgmii_in_txc[5];									
									
	end
	
	// octet 6 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet6_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet6_ctrl_flags[0] <= ~(xgmii_data_lane6[7]) & ~(xgmii_data_lane6[6]) & ~(xgmii_data_lane6[5]) & ~(xgmii_data_lane6[4]) &
											~(xgmii_data_lane6[3]) & xgmii_data_lane6[2] & xgmii_data_lane6[1] & xgmii_data_lane6[0] & 
											xgmii_in_txc[6];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet6_ctrl_flags[1] <= xgmii_data_lane6[7] & xgmii_data_lane6[6] & xgmii_data_lane6[5] & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & xgmii_data_lane6[0] & 
											xgmii_in_txc[6];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet6_ctrl_flags[2] <= ~(xgmii_data_lane6[7]) & ~(xgmii_data_lane6[6]) & ~(xgmii_data_lane6[5]) & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & ~(xgmii_data_lane6[0]) &   
											xgmii_in_txc[6];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet6_ctrl_flags[3] <= ~(xgmii_data_lane6[7]) & ~(xgmii_data_lane6[6]) & xgmii_data_lane6[5] & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & ~(xgmii_data_lane6[0]) &   
											xgmii_in_txc[6];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet6_ctrl_flags[4] <= ~(xgmii_data_lane6[7]) & xgmii_data_lane6[6] & xgmii_data_lane6[5] & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & ~(xgmii_data_lane6[0]) &   
											xgmii_in_txc[6];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										
			octet6_ctrl_flags[5] <= xgmii_data_lane6[7] & ~(xgmii_data_lane6[6]) & xgmii_data_lane6[5] & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & ~(xgmii_data_lane6[0]) &   
											xgmii_in_txc[6];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet6_ctrl_flags[6] <= xgmii_data_lane6[7] & xgmii_data_lane6[6] & ~(xgmii_data_lane6[5]) & xgmii_data_lane6[4] &
											xgmii_data_lane6[3] & xgmii_data_lane6[2] & ~(xgmii_data_lane6[1]) & ~(xgmii_data_lane6[0]) &   
											xgmii_in_txc[6];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet6_ctrl_flags[7] <= xgmii_data_lane6[7] & xgmii_data_lane6[6] & xgmii_data_lane6[5] & xgmii_data_lane6[4] & ~(xgmii_data_lane6[3]) & xgmii_data_lane6[2] &
											xgmii_data_lane6[1] & xgmii_data_lane6[0] & xgmii_in_txc[6];									
									
	end
	
	// octet 7 - Table 49-1, column 3, 8 characters
  always @ (posedge reset or posedge clock)
		if(reset == 1'b1) begin
			octet7_ctrl_flags <= {8{1'b0}};	
		end
		else begin
			//0. idle character /I/ - 0x07, 8'b0000_0111
			octet7_ctrl_flags[0] <= ~(xgmii_data_lane7[7]) & ~(xgmii_data_lane7[6]) & ~(xgmii_data_lane7[5]) & ~(xgmii_data_lane7[4]) &
											~(xgmii_data_lane7[3]) & xgmii_data_lane7[2] & xgmii_data_lane7[1] & xgmii_data_lane7[0] & 
											xgmii_in_txc[7];
											
			//1. terminate character /T/ - 0xfd, 8'b1111_1101										
			octet7_ctrl_flags[1] <= xgmii_data_lane7[7] & xgmii_data_lane7[6] & xgmii_data_lane7[5] & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & xgmii_data_lane7[0] & 
											xgmii_in_txc[7];
			
			//2. reserved0 character /R/b - 0x1c, 8'b0001_1100										
			octet7_ctrl_flags[2] <= ~(xgmii_data_lane7[7]) & ~(xgmii_data_lane7[6]) & ~(xgmii_data_lane7[5]) & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & ~(xgmii_data_lane7[0]) &   
											xgmii_in_txc[7];
											
			//3. reserved1 character  	- 0x3c, 8'b0011_1100										
			octet7_ctrl_flags[3] <= ~(xgmii_data_lane7[7]) & ~(xgmii_data_lane7[6]) & xgmii_data_lane7[5] & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & ~(xgmii_data_lane7[0]) &   
											xgmii_in_txc[7];								
											
			//4. reserved2 character /A/ - 0x7c, 8'b0111_1100										
			octet7_ctrl_flags[4] <= ~(xgmii_data_lane7[7]) & xgmii_data_lane7[6] & xgmii_data_lane7[5] & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & ~(xgmii_data_lane7[0]) &   
											xgmii_in_txc[7];								
											
			//5. reserved3 character /K/ - 0xbc, 8'b1011_1100										


			octet7_ctrl_flags[5] <= xgmii_data_lane7[7] & ~(xgmii_data_lane7[6]) & xgmii_data_lane7[5] & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & ~(xgmii_data_lane7[0]) &   
											xgmii_in_txc[7];								
			
			//6. reserved4 character    - 0xdc, 8'b1101_1100										
			octet7_ctrl_flags[6] <= xgmii_data_lane7[7] & xgmii_data_lane7[6] & ~(xgmii_data_lane7[5]) & xgmii_data_lane7[4] &
											xgmii_data_lane7[3] & xgmii_data_lane7[2] & ~(xgmii_data_lane7[1]) & ~(xgmii_data_lane7[0]) &   
											xgmii_in_txc[7];									
											
			//7. reserved5 character    - 0xf7, 8'b1111_0111										
			octet7_ctrl_flags[7] <= xgmii_data_lane7[7] & xgmii_data_lane7[6] & xgmii_data_lane7[5] & xgmii_data_lane7[4] &
											~(xgmii_data_lane7[3]) & xgmii_data_lane7[2] & xgmii_data_lane7[1] & xgmii_data_lane7[0] &   
											xgmii_in_txc[7];									
									
	end

 //----------------------------------------------------------------------------------------------
 // control characters that arrive from XGMII interface should be organized in control blocks.
 // The database of all possible control blocks (15 in total) is given below.
 //----------------------------------------------------------------------------------------------
 // control type continuous assignments - 56 bits are checked
 //14. 0x1E -> C0,C1,C2,C3,C4,C5,C6,C7
 assign type_control[14] = octet0_ctrl & ~(octet0_ctrl_flags[2]) & ~(octet0_ctrl_flags[3]) & octet1_ctrl &
									octet2_ctrl & octet3_ctrl & octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;
									
 //13. 0x2D -> C0,C1,C2,C3,O4,D5,D6,D7
 assign type_control[13] = octet0_ctrl & octet1_ctrl & octet2_ctrl & octet3_ctrl & 
									(octet4_ctrl_flags[3] | octet4_ctrl_flags[10]) & octet5_data & octet6_data & octet7_data; 
									
 //12. 0x33 -> C0,C1,C2,C3,S4,D5,D6,D7
 assign type_control[12] = octet0_ctrl & octet1_ctrl & octet2_ctrl & octet3_ctrl & 
									octet4_ctrl_flags[1] & octet5_data & octet6_data & octet7_data;
 
 //11. 0x66 -> O0,D1,D2,D3,S4,D5,D6,D7
 assign type_control[11] = (octet0_ctrl_flags[4] | octet0_ctrl_flags[11]) & octet1_data & octet2_data & octet3_data & 
									octet4_ctrl_flags[1] & octet5_data & octet6_data & octet7_data;
									
 //10. 0x55 -> O0,D1,D2,D3,O4,D5,D6,D7
 assign type_control[10] = (octet0_ctrl_flags[4] | octet0_ctrl_flags[11] ) & octet1_data & octet2_data & octet3_data &			
									(octet4_ctrl_flags[3] | octet4_ctrl_flags[10]) & octet5_data & octet6_data & octet7_data;
 
 //9. 0x78 -> S0,D1,D2,D3,D4,D5,D6,D7
 assign type_control[9] = octet0_ctrl_flags[1] & octet1_data & octet2_data & octet3_data &
									octet4_data & octet5_data & octet6_data & octet7_data;
 
 //8. 0x4B -> O0,D1,D2,D3,C4,C5,C6,C7
 assign type_control[8] = (octet0_ctrl_flags[4] | octet0_ctrl_flags[11]) & octet1_data & octet2_data & octet3_data &
									octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;

 //7. 0x87 -> T0,C1,C2,C3,C4,C5,C6,C7
 assign type_control[7] = octet0_ctrl_flags[2] & octet1_ctrl & octet2_ctrl & octet3_ctrl &
									octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;
 
 //6. 0x99 -> D0,T1,C2,C3,C4,C5,C6,C7
 assign type_control[6] = octet0_data & octet1_ctrl_flags[1] & octet2_ctrl & octet3_ctrl &
									octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;
 
 //5. 0xaa -> D0,D1,T2,C3,C4,C5,C6,C7
 assign type_control[5] = octet0_data & octet1_data & octet2_ctrl_flags[1] & octet3_ctrl &
									octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;
 
 //4. 0xb4 -> D0,D1,D2,T3,C4,C5,C6,C7
 assign type_control[4] = octet0_data & octet1_data & octet2_data & octet3_ctrl_flags[1] &
								  octet4_ctrl & octet5_ctrl & octet6_ctrl & octet7_ctrl;
 
 //3. 0xcc -> D0,D1,D2,D3,T4,C5,C6,C7
 assign type_control[3] = octet0_data & octet1_data & octet2_data & octet3_data &
									octet4_ctrl_flags[2] & octet5_ctrl & octet6_ctrl & octet7_ctrl;
 
 //2. 0xd2 -> D0,D1,D2,D3,D4,T5,C6,C7
 assign type_control[2] = octet0_data & octet1_data & octet2_data & octet3_data &
									octet4_data & octet5_ctrl_flags[1] & octet6_ctrl & octet7_ctrl;
									
 //1. 0xe1 -> D0,D1,D2,D3,D4,D5,T6,C7
 assign type_control[1] = octet0_data & octet1_data & octet2_data & octet3_data &
									octet4_data & octet5_data & octet6_ctrl_flags[1] & octet7_ctrl;
									
 //0. 0xff -> D0,D1,D2,D3,D4,D5,D6,T7
 assign type_control[0] = octet0_data & octet1_data & octet2_data & octet3_data &
									octet4_data & octet5_data & octet6_data & octet7_ctrl_flags[1];


	
	//keep database in the register
	always @ (posedge clock or posedge reset) begin
			if(reset == 1'b1) begin
					type_control_reg <= {15{1'b0}};
					type_data_reg <= 1'b0;						
			end
			else begin
					type_control_reg <= type_control;
					type_data_reg <= type_data;					
			end	
	end
 
	// move data from xgmii_data_reg to 10GBaseR registers
	always @ (posedge clock or posedge reset) begin
			if(reset == 1'b1) begin
					GBaseR_data_regs <= {64{1'b0}};
			end
			else begin
					GBaseR_data_regs <= xgmii_data_regs;
			end	
	end
 
 //-----------------------------------------------------------------------------------------
 // if incoming data contains control sequences, we need to translate 8-bit XGMII codes into
 // 7-bit/4-bit 10GBASE-R codes. Pure data sequences are not encoded and transferred to the
 // output directly from registers - xgmii_data_regs[63:0]. 
 
	// encoding of lane0 - all seq. apart those encoded by a block type code, i.e. /S/,/T/,/Q/,/Fsig/
	always @ (posedge clock) begin
			if (octet0_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C0 <= {7{1'b0}};					
			end 
			else if(octet0_ctrl_flags[5] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C0 <= 7'b0101101;
			end 
			else if(octet0_ctrl_flags[6] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C0 <= 7'b0110011;
			end
			else if(octet0_ctrl_flags[7] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C0 <= 7'b1001011;
			end
			else if(octet0_ctrl_flags[8] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C0 <= 7'b1010101;
			end
			else if(octet0_ctrl_flags[9] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C0 <= 7'b1100110;
			end
			else if(octet0_ctrl_flags[10] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C0 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C0 <= 7'b0011110;
			end
	end
	
	// lane1 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet1_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C1 <= {7{1'b0}};					
			end 
			else if(octet1_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C1 <= 7'b0101101;
			end //here
			else if(octet1_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C1 <= 7'b0110011;
			end
			else if(octet1_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C1 <= 7'b1001011;
			end
			else if(octet1_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C1 <= 7'b1010101;
			end
			else if(octet1_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C1 <= 7'b1100110;
			end
			else if(octet1_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C1 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C1 <= 7'b0011110;
			end	
	end
	 
	// lane2 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet2_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C2 <= {7{1'b0}};					
			end 
			else if(octet2_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C2 <= 7'b0101101;
			end //here
			else if(octet2_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C2 <= 7'b0110011;
			end
			else if(octet2_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C2 <= 7'b1001011;
			end
			else if(octet2_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C2 <= 7'b1010101;
			end
			else if(octet2_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C2 <= 7'b1100110;

			end
			else if(octet2_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C2 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C2 <= 7'b0011110;
			end	
	end
	
	
	// lane3 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet3_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C3 <= {7{1'b0}};					
			end 
			else if(octet3_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C3 <= 7'b0101101;
			end //here
			else if(octet3_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C3 <= 7'b0110011;
			end
			else if(octet3_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C3 <= 7'b1001011;
			end
			else if(octet3_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C3 <= 7'b1010101;
			end
			else if(octet3_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C3 <= 7'b1100110;
			end
			else if(octet3_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C3 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C3 <= 7'b0011110;
			end	
	end
	
	// lane4 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet4_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C4 <= {7{1'b0}};					
			end 
			else if(octet4_ctrl_flags[4] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C4 <= 7'b0101101;
			end //here
			else if(octet4_ctrl_flags[5] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C4 <= 7'b0110011;
			end
			else if(octet4_ctrl_flags[6] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C4 <= 7'b1001011;
			end
			else if(octet4_ctrl_flags[7] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C4 <= 7'b1010101;
			end
			else if(octet4_ctrl_flags[8] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C4 <= 7'b1100110;
			end
			else if(octet4_ctrl_flags[9] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C4 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C4 <= 7'b0011110;
			end	
	end
  
   // lane5 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet5_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C5 <= {7{1'b0}};					
			end 
			else if(octet5_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C5 <= 7'b0101101;
			end //here
			else if(octet5_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C5 <= 7'b0110011;
			end
			else if(octet5_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C5 <= 7'b1001011;
			end
			else if(octet5_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C5 <= 7'b1010101;
			end
			else if(octet5_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C5 <= 7'b1100110;
			end
			else if(octet5_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C5 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C5 <= 7'b0011110;
			end	
	end
 
	// lane6 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet6_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C6 <= {7{1'b0}};					
			end 
			else if(octet6_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C6 <= 7'b0101101;
			end 
			else if(octet6_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C6 <= 7'b0110011;
			end
			else if(octet6_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C6 <= 7'b1001011;
			end
			else if(octet6_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C6 <= 7'b1010101;
			end
			else if(octet6_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C6 <= 7'b1100110;
			end
			else if(octet6_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C6 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C6 <= 7'b0011110;
			end	
	end
	
	// lane7 encoding - except /S/,/T/,/Q/,/Fsig/.
	always @ (posedge clock) begin
			if (octet7_ctrl_flags[0] == 1'b1) begin			//idle -> 0x00 code
					GBaseR_C7 <= {7{1'b0}};					
			end 
			else if(octet7_ctrl_flags[2] == 1'b1) begin 	//res0 -> 0x2D code 
					GBaseR_C7 <= 7'b0101101;
			end 
			else if(octet7_ctrl_flags[3] == 1'b1) begin 	//res1 -> 0x33 code 
					GBaseR_C7 <= 7'b0110011;
			end
			else if(octet7_ctrl_flags[4] == 1'b1) begin 	//res2 -> 0x4B code 
					GBaseR_C7 <= 7'b1001011;
			end
			else if(octet7_ctrl_flags[5] == 1'b1) begin 	//res3 -> 0x55 code 
					GBaseR_C7 <= 7'b1010101;
			end
			else if(octet7_ctrl_flags[6] == 1'b1) begin 	//res4 -> 0x66 code 
					GBaseR_C7 <= 7'b1100110;
			end
			else if(octet7_ctrl_flags[7] == 1'b1) begin 	//res5 -> 0x78 code 
					GBaseR_C7 <= 7'b1111000;
			end
			else begin 										//error -> 0x1e code 
					GBaseR_C7 <= 7'b0011110;
			end	
	end
 
 
	// O0 and O4 codes are not standard (7-bit codes) and contain only 4-bits	
	// there are 2 possibilities - either /Q/ or /Fsig/ sequences of ordered set
	always @ (posedge clock) begin
			if(octet0_ctrl_flags[11] == 1'b1) begin //if /Fsig/
				GBaseR_O0 <= {4{1'b1}};						//0xF		
			end
			else begin 								//if /Q/
				GBaseR_O0 <= {4{1'b0}};						//0x0		
			end
	end
	
	always @ (posedge clock) begin
			if(octet4_ctrl_flags[10] == 1'b1) begin //if /Fsig/
				GBaseR_O4 <= {4{1'b1}};						//0xF		
			end
			else begin 								//if /Q/
				GBaseR_O4 <= {4{1'b0}};						//0x0		
			end
			
	end


   // assignment of the block type field
 	always @ (posedge clock or posedge reset) begin	//check sending order
			if(reset == 1'b1) begin 
					out_type_field <= {8{1'b0}};
			end
			else begin
				 if (type_data_reg == 1'b0) begin
					if(type_control_reg[0] == 1'b1) begin			// 0xFF -> D0,D1,D2,D3,D4,D5,D6,T7
							out_type_field <= {8{1'b1}}; 
					end
					else if (type_control_reg[1] == 1'b1) begin		// 0xE1 -> D0,D1,D2,D3,D4,D5,T6,C7
							out_type_field <= 8'b11100001;	
					end
					else if (type_control_reg[2] == 1'b1) begin		// 0xD2 -> D0,D1,D2,D3,D4,T5,C6,C7
							out_type_field <= 8'b11010010;	
					end
					else if (type_control_reg[3] == 1'b1) begin		// 0xCC -> D0,D1,D2,D3,T4,C5,C6,C7
							out_type_field <= 8'b11001100;	
					end
					else if (type_control_reg[4] == 1'b1) begin		// 0xB4 -> D0,D1,D2,T3,C4,C5,C6,C7
							out_type_field <= 8'b10110100;	
					end
					else if (type_control_reg[5] == 1'b1) begin		// 0xAA -> D0,D1,T2,C3,C4,C5,C6,C7
							out_type_field <= 8'b10101010;	
					end
					else if (type_control_reg[6] == 1'b1) begin		// 0x99 -> D0,T1,C2,C3,C4,C5,C6,C7
							out_type_field <= 8'b10011001;	
					end
					else if (type_control_reg[7] == 1'b1) begin		// 0x87 -> T0,C1,C2,C3,C4,C5,C6,C7
							out_type_field <= 8'b10000111;	
					end
					else if (type_control_reg[8] == 1'b1) begin		// 0x4B -> O0,D1,D2,D3,C4,C5,C6,C7
							out_type_field <= 8'b01001011;	
					end
					else if (type_control_reg[9] == 1'b1) begin		// 0x78 -> S0,D1,D2,D3,D4,D5,D6,D7
							out_type_field <= 8'b01111000;	
					end
					else if (type_control_reg[10] == 1'b1) begin		// 0x55 -> O0,D1,D2,D3,O4,D5,D6,D7
							out_type_field <= 8'b01010101;	
					end
					else if (type_control_reg[11] == 1'b1) begin		// 0x66 -> O0,D1,D2,D3,S4,D5,D6,D7
							out_type_field <= 8'b01100110;	
					end
					else if (type_control_reg[12] == 1'b1) begin		// 0x33 -> C0,C1,C2,C3,S4,D5,D6,D7
							out_type_field <= 8'b00110011;	
					end
					else if (type_control_reg[13] == 1'b1) begin		// 0x2D -> C0,C1,C2,C3,O4,D5,D6,D7
							out_type_field <= 8'b00101101;	
					end
					else if (type_control_reg[14] == 1'b1) begin		// 0x1E -> C0,C1,C2,C3,C4,C5,C6,C7
							out_type_field <= 8'b00011110;	
					end
					else if (type_prob_ctrl == 1'b1) begin			// there are control bits, but not in type_control_reg
						out_type_field <= 8'b00011110;
					end	
				end
				else begin							// case of pure data
					out_type_field[7:0] <= GBaseR_data_regs[7:0];
				end
			end			
	end
	
	// assigning synchronization header - 01/data only 10/misture
	always @ (posedge clock or posedge reset) begin
			if(reset == 1'b1) begin
					out_sync_header <= 2'b01;								// 10 control by default
			end
			else begin
				 if (type_data_reg && (type_control_reg == 0)) begin
						out_sync_header <= 2'b10;								// 01 - reverse due to the sending order
				end
				else begin
						out_sync_header <= 2'b01;								// 10
				end	
			end

	end
	
	
	//-------------------------------------------------------------------------------
	//assemble resulting frames considering sync header, typefield, control sequences 
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
				out_data <= {56{1'b0}};
				out_invalid <= 1'b1;				//invalid by default
			end 
			else begin
				 if(type_data_reg == 1'b0) begin
					if(type_control_reg[14] == 1'b1) begin				// 0x1E -> C0,C1,C2,C3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_C3, GBaseR_C2, GBaseR_C1, GBaseR_C0};	
							out_invalid <= 1'b0;	
					end
					else if(type_control_reg[13] == 1'b1) begin				// 0x2D -> C0,C1,C2,C3,O4,D5,D6,D7
							out_data <= {GBaseR_data_regs[63:40], GBaseR_O4[3:0], GBaseR_C3, GBaseR_C2, GBaseR_C1, GBaseR_C0};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[12] == 1'b1) begin				// 0x33 -> C0,C1,C2,C3,S4,D5,D6,D7
							out_data <= {GBaseR_data_regs[63:40], 4'b0000, GBaseR_C3, GBaseR_C2, GBaseR_C1, GBaseR_C0};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[11] == 1'b1) begin				// 0x66 -> O0,D1,D2,D3,S4,D5,D6,D7
							out_data <= {GBaseR_data_regs[63:40], 4'b0000, GBaseR_O0, GBaseR_data_regs[31:8]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[10] == 1'b1) begin				// 0x55 -> O0,D1,D2,D3,O4,D5,D6,D7
							out_data <= {GBaseR_data_regs[63:40], GBaseR_O4[3:0], GBaseR_O0, GBaseR_data_regs[31:8]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[9] == 1'b1) begin				// 0x78 -> S0,D1,D2,D3,D4,D5,D6,D7
							out_data <= {GBaseR_data_regs[63:8]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[8] == 1'b1) begin				// 0x4B -> O0,D1,D2,D3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_O0, GBaseR_data_regs[31:8]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[7] == 1'b1) begin				// 0x87 -> T0,C1,C2,C3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_C3, GBaseR_C2, GBaseR_C1, 7'b0000000};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[6] == 1'b1) begin				// 0x99 -> D0,T1,C2,C3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_C3, GBaseR_C2, 6'b000000, GBaseR_data_regs[7:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[5] == 1'b1) begin				// 0xAA -> D0,D1,T2,C3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_C3, 5'b00000, GBaseR_data_regs[15:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[4] == 1'b1) begin				// 0xB4 -> D0,D1,D2,T3,C4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, 4'b0000, GBaseR_data_regs[23:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[3] == 1'b1) begin				// 0xCC -> D0,D1,D2,D3,T4,C5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, 3'b000, GBaseR_data_regs[31:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[2] == 1'b1) begin				// 0xD2 -> D0,D1,D2,D3,D4,T5,C6,C7
							out_data <= {GBaseR_C7, GBaseR_C6, 2'b00, GBaseR_data_regs[39:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[1] == 1'b1) begin				// 0xE1 -> D0,D1,D2,D3,D4,D5,T6,C7
							out_data <= {GBaseR_C7, 1'b0, GBaseR_data_regs[47:0]};
							out_invalid <= 1'b0;
					end
					else if(type_control_reg[0] == 1'b1) begin				// 0xFF -> D0,D1,D2,D3,D4,D5,D6,T7
							out_data <= {GBaseR_data_regs[55:0]};
							out_invalid <= 1'b0;
					end
					else if(type_prob_ctrl == 1'b1) begin
						out_data <= {GBaseR_C7, GBaseR_C6, GBaseR_C5, GBaseR_C4, GBaseR_C3, GBaseR_C2, GBaseR_C1, GBaseR_C0};
						out_invalid <= 1'b1;
					end
				end	
				else begin							// data sequence	
					out_data <= {GBaseR_data_regs[63:8]};
					out_invalid <= 1'b0;
				end
			end				
	end
		
	assign mult_out_txd = {out_data, out_type_field, out_sync_header};
	


	// FSM to distinguish type of the output frame

	// [14] - 0x1E, [13] - 0x2D, [12] - 0x33, [11] - 0x66 , [10] - 0x55, 
 	// [9] - 0x78, [8] - 0x4B, [7] - 0x87, [6] - 0x99, [5] - 0xAA, 
	// [4] - 0xB4, [3] - 0xCC, [2] - 0xD2, [1] - 0xE1, [0] - 0xFF	
	always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			frame_type_reg <= ctrl_frame;
		end
		else begin
			if( (type_control_reg[14] == 1'b1) | (type_control_reg[13] == 1'b1) | (type_control_reg[10] == 1'b1) | (type_control_reg[8] == 1'b1) ) begin
				frame_type_reg <= ctrl_frame;
			end
			else if ((type_control_reg[12] == 1'b1) | (type_control_reg[11] == 1'b1) | (type_control_reg[9] == 1'b1)) begin
				frame_type_reg <= start_frame;
			end
			else if ((type_control_reg[7] == 1'b1) | (type_control_reg[6] == 1'b1) | (type_control_reg[5] == 1'b1) | (type_control_reg[4] == 1'b1) |
				 (type_control_reg[3] == 1'b1) | (type_control_reg[2] == 1'b1) | (type_control_reg[1] == 1'b1) | (type_control_reg[0] == 1'b1) ) begin
				frame_type_reg <= terminate_frame;
			end
			else if (type_data_reg == 1'b1) begin
				frame_type_reg <= data_frame;	
			end
			else begin
				frame_type_reg <= illegal_frame;
			end
		end
	end	
	assign frame_type = frame_type_reg;	

	
	// registers that keep the final output (should comply)
	// if out_invalid - type field is set to 0x00 - e.g. is not defined
	// and decoder will detect an error
	always @ (posedge clock  or posedge reset) begin
			if (reset == 1'b1) begin
				out_txd[65:0] <= {66{1'b0}};				
			end
			else begin				
				out_txd[65:0] <= mult_out_txd[65:0];					
			end
	end
	
	
endmodule

  
