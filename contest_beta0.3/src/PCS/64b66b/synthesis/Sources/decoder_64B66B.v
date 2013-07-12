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
// Description: 64b66b decoding performs transformation of 10GBASE-R format into XGMII format.
// 10GBASE-R input sequences are: 64-bit data sequence and 2-bit synchronization header (received from descrambler).
// 64-bit sequence is split into 8 octets and back formated to XGMII sequence using rules specified in clause 49.
// Data octets are not modified by decoder. Control octects are back formated to XGMII representations. 
// 
//////////////////////////////////////////////////////////////////////////////////
module decoder_64B66B(gbaser_txd, xgmii_in_txd, xgmii_in_txc, invalid_code, sync_enabled ,reset, clock);

// frames arrive in the following format:
//	[sync(01)]/[data(8 octets)]  
//						OR
//	[sync(10)]/[type(8bit)]/[data/O fields/C fields] - 15 different combinations
// 

// input/output data 
  input [65:0] 	gbaser_txd; 
  input reset;
  input clock;
  input sync_enabled;				//dec. is synchronized; 01/10 transition is detected
  output wire [63:0] 	xgmii_in_txd;
  output wire [7:0] 	xgmii_in_txc;
  output wire invalid_code;
  
  // 66 bit frame is split into 3 parts: synch header/type field/data
  wire [65:0] gbaser_data;	
  wire [7:0]  gbaser_type_field;
  wire [1:0]  gbaser_sync_head;
 
 // if header is 01 - data can be sent to the out
  reg [65:0] input_data_regs1;
   
 // incoming sequence - control or data
  wire type_ctrl;
  wire type_data;
  reg  type_invalid_code;
  wire  type_invalid_sync;
 // flags of all possible type field blocks - Figure 49-7
 // -----------------------------------------------------------------------------
 // [14] - 0x1E, [13] - 0x2D, [12] - 0x33, [11] - 0x66 , [10] - 0x55, 
 // [9] - 0x78, [8] - 0x4B, [7] - 0x87, [6] - 0x99, [5] - 0xAA, 
 // [4] - 0xB4, [3] - 0xCC, [2] - 0xD2, [1] - 0xE1, [0] - 0xFF
 wire [14:0] type_classifier; 
 reg [14:0] type_classifier_reg; 

 wire [2:0] out_type;
 reg [2:0] out_type_reg;

 parameter [2:0] ctrl_frame = 3'b001;
 parameter [2:0] start_frame = 3'b010;
 parameter [2:0] terminate_frame = 3'b011;
 parameter [2:0] data_frame = 3'b100;
 parameter [2:0] error_frame = 3'b101;
 
 // xgmii values of C0-C7 codes
 reg [7:0] C0_code;
 reg [7:0] C1_code;
 reg [7:0] C2_code;
 reg [7:0] C3_code;
 reg [7:0] C4_code;
 reg [7:0] C5_code;
 reg [7:0] C6_code;
 reg [7:0] C7_code;
 
 // xgmii values of O0 and O4 codes
 // if 0x0 - 0x9C, else if 0xF - 0x5C
 reg [1:0] O0_code_flag;	// [1] - gbaser 0xF , [0] - gbaser 0x0
 reg [1:0] O4_code_flag;	// [1] - gbaser 0xF , [0] - gbaser 0x0
 reg [7:0] O0_code;			// xgmii 0x9c or 0x5c
 reg [7:0] O4_code;			// xgmii 0x9c or 0x5c

 
 // -----------------------------------------------------------------------------
 // the output data 
 // 8 octets in xgmii format
 reg [7:0] xgmii_octet0;
 reg [7:0] xgmii_octet1;
 reg [7:0] xgmii_octet2;
 reg [7:0] xgmii_octet3;
 reg [7:0] xgmii_octet4;
 reg [7:0] xgmii_octet5;
 reg [7:0] xgmii_octet6;
 reg [7:0] xgmii_octet7;
 
 // the output data 
 //8 control characters
 reg xgmii_ctrl0;
 reg xgmii_ctrl1;
 reg xgmii_ctrl2;
 reg xgmii_ctrl3;
 reg xgmii_ctrl4;
 reg xgmii_ctrl5;
 reg xgmii_ctrl6;
 reg xgmii_ctrl7;
 
	// --------------------------------------------------------
	// assign arriving sequence
	assign gbaser_data = gbaser_txd;
	assign gbaser_type_field = gbaser_txd[9:2];
	assign gbaser_sync_head = gbaser_txd[1:0];
 
	// place arriving data into the register
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					input_data_regs1 <= {66{1'b0}};
			end
			else begin 
				if(sync_enabled == 1'b0) begin
						input_data_regs1 <= {66{1'b0}};
				end
				else begin
						input_data_regs1[65:0] <= gbaser_data[65:0];
				end
			end
	end	
	
	// check whether sequence is ctrl or data
	assign type_data = ~(gbaser_sync_head[0]) & gbaser_sync_head[1];
	assign type_ctrl = gbaser_sync_head[0] & ~(gbaser_sync_head[1]);
	assign type_invalid_sync = ~(gbaser_sync_head[0] & !gbaser_sync_head[1]) | (gbaser_sync_head[0] & gbaser_sync_head[1]);
 
	// generate all possible block type fields
	//[14] - 0x1E -> C0,C1,C2,C3,C4,C5,C6,C7
	assign type_classifier[14] = ~(gbaser_type_field[7]) & ~(gbaser_type_field[6]) & ~(gbaser_type_field[5]) & gbaser_type_field[4] &
									     gbaser_type_field[3] &  gbaser_type_field[2] & gbaser_type_field[1] & ~(gbaser_type_field[0]) & 
										  type_ctrl;
	//[13] - 0x2D -> C0,C1,C2,C3,O4,D5,D6,D7										 
	assign type_classifier[13] = ~(gbaser_type_field[7]) & ~(gbaser_type_field[6]) & gbaser_type_field[5] & ~(gbaser_type_field[4]) &
									     gbaser_type_field[3] &  gbaser_type_field[2] & ~(gbaser_type_field[1]) & gbaser_type_field[0] & 
										  type_ctrl;
	//[12] - 0x33 -> C0,C1,C2,C3,S4,D5,D6,D7										 
	assign type_classifier[12] = ~(gbaser_type_field[7]) & ~(gbaser_type_field[6]) & gbaser_type_field[5] & gbaser_type_field[4] &
									     ~(gbaser_type_field[3]) & ~(gbaser_type_field[2]) & gbaser_type_field[1] & gbaser_type_field[0] &
										  type_ctrl;										 
	//[11] - 0x66 -> O0,D1,D2,D3,S4,D5,D6,D7										
	assign type_classifier[11] = ~(gbaser_type_field[7]) & gbaser_type_field[6] & gbaser_type_field[5] & ~(gbaser_type_field[4]) &
									     ~(gbaser_type_field[3]) & gbaser_type_field[2] & gbaser_type_field[1] & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[10] - 0x55 -> O0,D1,D2,D3,O4,D5,D6,D7										
	assign type_classifier[10] = ~(gbaser_type_field[7]) & gbaser_type_field[6] & ~(gbaser_type_field[5]) & gbaser_type_field[4] &
									     ~(gbaser_type_field[3]) & gbaser_type_field[2] & ~(gbaser_type_field[1]) & gbaser_type_field[0] &
										  type_ctrl;
	//[9] - 0x78 -> S0,D1,D2,D3,D4,D5,D6,D7										
	assign type_classifier[9] = ~(gbaser_type_field[7]) & gbaser_type_field[6] & gbaser_type_field[5] & gbaser_type_field[4] &
									     gbaser_type_field[3] & ~(gbaser_type_field[2]) & ~(gbaser_type_field[1]) & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[8] - 0x4B -> O0,D1,D2,D3,C4,C5,C6,C7
	assign type_classifier[8] = ~(gbaser_type_field[7]) & gbaser_type_field[6] & ~(gbaser_type_field[5]) & ~(gbaser_type_field[4]) &
									     gbaser_type_field[3] & ~(gbaser_type_field[2]) & gbaser_type_field[1] & gbaser_type_field[0] &
										  type_ctrl;
	//[7] - 0x87 -> T0,C1,C2,C3,C4,C5,C6,C7
	assign type_classifier[7] =  gbaser_type_field[7] & ~(gbaser_type_field[6]) & ~(gbaser_type_field[5]) & ~(gbaser_type_field[4]) &
									     ~(gbaser_type_field[3]) & gbaser_type_field[2] & gbaser_type_field[1] & gbaser_type_field[0] & 
										  type_ctrl;
	//[6] - 0x99 -> D0,T1,C2,C3,C4,C5,C6,C7										
	assign type_classifier[6] =  gbaser_type_field[7] & ~(gbaser_type_field[6]) & ~(gbaser_type_field[5]) & gbaser_type_field[4] &
									     gbaser_type_field[3] & ~(gbaser_type_field[2]) & ~(gbaser_type_field[1]) & gbaser_type_field[0] &
										  type_ctrl;
	//[5] - 0xAA -> D0,D1,T2,C3,C4,C5,C6,C7
	assign type_classifier[5] =  gbaser_type_field[7] & ~(gbaser_type_field[6]) & gbaser_type_field[5] & ~(gbaser_type_field[4]) &
									     gbaser_type_field[3] & ~(gbaser_type_field[2]) & gbaser_type_field[1] & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[4] - 0xB4 -> D0,D1,D2,T3,C4,C5,C6,C7
	assign type_classifier[4] =  gbaser_type_field[7] & ~(gbaser_type_field[6]) & gbaser_type_field[5] & gbaser_type_field[4] &
									     ~(gbaser_type_field[3]) & gbaser_type_field[2] & ~(gbaser_type_field[1]) & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[3] - 0xCC -> D0,D1,D2,D3,T4,C5,C6,C7
	assign type_classifier[3] =  gbaser_type_field[7] & gbaser_type_field[6] & ~(gbaser_type_field[5]) & ~(gbaser_type_field[4]) &
									     gbaser_type_field[3] & gbaser_type_field[2] & ~(gbaser_type_field[1]) & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[2] - 0xD2 -> D0,D1,D2,D3,D4,T5,C6,C7
	assign type_classifier[2] =  gbaser_type_field[7] & gbaser_type_field[6] & ~(gbaser_type_field[5]) & gbaser_type_field[4] &
									     ~(gbaser_type_field[3]) & ~(gbaser_type_field[2]) & gbaser_type_field[1] & ~(gbaser_type_field[0]) &
										  type_ctrl;
	//[1] - 0xE1 -> D0,D1,D2,D3,D4,D5,T6,C7
	assign type_classifier[1] =  gbaser_type_field[7] & gbaser_type_field[6] & gbaser_type_field[5] & ~(gbaser_type_field[4]) &
									     ~(gbaser_type_field[3]) & ~(gbaser_type_field[2]) & ~(gbaser_type_field[1]) & gbaser_type_field[0] &
										  type_ctrl;
	//[0] - 0xFF -> D0,D1,D2,D3,D4,D5,D6,T7
	assign type_classifier[0] =  gbaser_type_field[7] & gbaser_type_field[6] & gbaser_type_field[5] & gbaser_type_field[4] &
									     gbaser_type_field[3] & gbaser_type_field[2] & gbaser_type_field[1] & gbaser_type_field[0] & 
										  type_ctrl;
 
 
	// keep type field in registers
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					type_classifier_reg <= {15{1'b0}};
			end
			else begin 
				if (sync_enabled == 1'b0) begin
						type_classifier_reg <= {15{1'b0}};
				end
				else begin
						type_classifier_reg <= type_classifier;
				end
			end
	end
	
	// Position control characters in the code word i.e. - C0,C1...C7 and O0/O4 always have
	// similar positions in each control word. All possible combinations of C0...C7 GBASE-R
	// like res0...res5, error, idle are known and can be decoded into 8-bit xgmii.
	// O0,O4 sequences also keep fixed positions and are known, other characters, like start
	//	and term., are encoded by a type field.
 
   //Code C0 
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C0_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C0_code <= {8{1'b0}};
				end
				else begin
					if (gbaser_data[16:10] == 7'b0000000) begin			// 0x00 - idle gbaser
							C0_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[16:10] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C0_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[16:10] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C0_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[16:10] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C0_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[16:10] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C0_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[16:10] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C0_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[16:10] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C0_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C0_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
			
	end
	
	//Code C1
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C1_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C1_code <= {8{1'b0}};
				end
				else begin
					if (gbaser_data[23:17] == 7'b0000000) begin			// 0x00 - idle gbaser
							C1_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[23:17] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C1_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[23:17] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C1_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[23:17] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C1_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[23:17] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C1_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[23:17] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C1_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[23:17] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C1_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C1_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
	
	//Code C2
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
				C2_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C2_code <= {8{1'b0}};
				end
				else begin
					if (gbaser_data[30:24] == 7'b0000000) begin		// 0x00 - idle gbaser
							C2_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[30:24] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C2_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[30:24] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C2_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[30:24] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C2_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[30:24] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C2_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[30:24] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C2_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[30:24] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C2_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin											// 0x1E - error gbaser
							C2_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
	
	//Code C3
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C3_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C3_code <= {8{1'b0}};
				end
				else begin 
					if (gbaser_data[37:31] == 7'b0000000) begin		// 0x00 - idle gbaser
							C3_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[37:31] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C3_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[37:31] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C3_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[37:31] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C3_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[37:31] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C3_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[37:31] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C3_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[37:31] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C3_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C3_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
	
	//Code C4
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
				C4_code <= {8{1'b0}};
			end
			else begin
			 	if (sync_enabled == 1'b0) begin
					C4_code <= {8{1'b0}};
				end
				else begin 
					if (gbaser_data[44:38] == 7'b0000000) begin			// 0x00 - idle gbaser
							C4_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[44:38] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C4_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[44:38] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C4_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[44:38] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C4_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[44:38] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C4_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[44:38] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C4_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[44:38] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C4_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C4_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
	
	//Code C5
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C5_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C5_code <= {8{1'b0}};
				end
				else begin 
					if (gbaser_data[51:45] == 7'b0000000) begin			// 0x00 - idle gbaser
							C5_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[51:45] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C5_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[51:45] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C5_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[51:45] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C5_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[51:45] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C5_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[51:45] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C5_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[51:45] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C5_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C5_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
 
	//Code C6
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C6_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C6_code <= {8{1'b0}};
				end
				else begin 
					if (gbaser_data[58:52] == 7'b0000000) begin			// 0x00 - idle gbaser
							C6_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[58:52] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C6_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[58:52] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C6_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[58:52] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C6_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[58:52] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C6_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[58:52] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C6_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[58:52] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C6_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C6_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end
			end
	end
 
	//Code C7
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					C7_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					C7_code <= {8{1'b0}};
				end
				else begin
					if (gbaser_data[65:59] == 7'b0000000) begin			// 0x00 - idle gbaser
							C7_code <= 8'b00000111;								// 0x07 - idle xgmii	
					end 
					else if(gbaser_data[65:59] == 7'b0101101) begin		// 0x2D - res0 gbaser
							C7_code <= 8'b00011100;								// 0x1C - res0 xgmii	
					end
					else if(gbaser_data[65:59] == 7'b0110011) begin		// 0x33 - res1 gbaser
							C7_code <= 8'b00111100;								// 0x3C - res1 xgmii	
					end
					else if(gbaser_data[65:59] == 7'b1001011) begin		// 0x4B - res2 gbaser
							C7_code <= 8'b01111100;								// 0x7C - res2 xgmii	
					end
					else if(gbaser_data[65:59] == 7'b1010101) begin		// 0x55 - res3 gbaser
							C7_code <= 8'b10111100;								// 0xBC - res3 xgmii	
					end
					else if(gbaser_data[65:59] == 7'b1100110) begin		// 0x66 - res4 gbaser
							C7_code <= 8'b11011100;								// 0xDC - res4 xgmii	
					end
					else if(gbaser_data[65:59] == 7'b1111000) begin		// 0x78 - res5 gbaser
							C7_code <= 8'b11110111;								// 0xF7 - res5 xgmii	
					end
					else begin														// 0x1E - error gbaser
							C7_code <= 8'b11111110;								// 0xFE - error xgmii	
					end
				end			
			end
	end
	
	// create ordered set flags
	// O0 and O4 sets are always at the same positions
	// O0 - positions [37:34], types 0x66, 0x55, 0x4b.
 	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
				O0_code_flag <= {2{1'b0}};
				O0_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
					O0_code_flag <= {2{1'b0}};
					O0_code <= {8{1'b0}};
				end
				else begin		
					if((gbaser_data[37:34] == 4'b0000) & ((type_classifier[8] == 1'b1) | (type_classifier[10] == 1'b1) | (type_classifier[11] == 1'b1))) begin
							O0_code_flag[0] <= 1'b1;		//gbaser 0x0
							O0_code_flag[1] <= 1'b0;
							O0_code <= 8'b10011100;			//xgmii 0x9C
					end
					else if ((gbaser_data[37:34] == 4'b1111) & ((type_classifier[8] == 1'b1) | (type_classifier[10] == 1'b1) | (type_classifier[11] == 1'b1))) begin
							O0_code_flag[1] <= 1'b1;		//gbaser 0xF
							O0_code_flag[0] <= 1'b0;
							O0_code <= 8'b01011100;			//xgmii 0x5C
					end
				end
			end
	end
	
	//	O4 - positions [41:38], types 0x55, 0x2d
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
				O4_code_flag <= {2{1'b0}};
				O4_code <= {8{1'b0}};
			end
			else begin
				if (sync_enabled == 1'b0) begin
						O4_code_flag <= {2{1'b0}};
						O4_code <= {8{1'b0}};
				end
				else begin		
					if((gbaser_data[41:38] == 4'b0000) & ((type_classifier[10] == 1'b1) | (type_classifier[13] == 1'b1))) begin
							O4_code_flag[0] <= 1'b1;		//gbaser 0x0
							O4_code_flag[1] <= 1'b0;
							O4_code <= 8'b10011100;			//xgmii 0x9C
					end
					else if ((gbaser_data[41:38] == 4'b1111) & ((type_classifier[10] == 1'b1) | (type_classifier[13] == 1'b1))) begin
							O4_code_flag[1] <= 1'b1;		//gbaser 0xF
							O4_code_flag[0] <= 1'b0;
							O4_code <= 8'b01011100;			//xgmii 0x5C
					end
				end
			end
	end
		
	//---------------------------------------------------------------------------------------------------------------
	// encoding gbaser bytes into xgmii seqs. octet by octet
	// type_classifier: [14] - 0x1E, [13] - 0x2D, [12] - 0x33, [11] - 0x66 , [10] - 0x55, 
	// [9] - 0x78, [8] - 0x4B, [7] - 0x87, [6] - 0x99, [5] - 0xAA, 
	// [4] - 0xB4, [3] - 0xCC, [2] - 0xD2, [1] - 0xE1, [0] - 0xFF
	
	// Octet 0
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet0 <= {8{1'b0}};
					xgmii_ctrl0 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet0 <= {8{1'b0}};
					xgmii_ctrl0 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14:12] != 3'b000) begin	
								xgmii_octet0 <= C0_code;						// types - 0x1E, 0x2D, 0x33 -> C0 7-bit control
								xgmii_ctrl0 <= 1'b1;
					end
					else if(((type_classifier_reg[8] == 1'b1 )| (type_classifier_reg[10] == 1'b1 ) | (type_classifier_reg[11] == 1'b1 )) & (O0_code_flag[0] == 1'b1)) begin
								xgmii_octet0 <= O0_code;						// types - 0x66, 0x55, 0x4B -> O0 4-bit control
								xgmii_ctrl0 <= 1'b1;
					end
					else if(((type_classifier_reg[8] == 1'b1 ) | (type_classifier_reg[10] == 1'b1 ) | (type_classifier_reg[11] == 1'b1 )) & (O0_code_flag[1] == 1'b1)) begin
								xgmii_octet0 <= O0_code;						// types - 0x66, 0x55, 0x4B -> O0 4-bit control
								xgmii_ctrl0 <= 1'b1;
					end
					else if (type_classifier_reg[9] == 1'b1) begin
								xgmii_octet0 <= 8'b11111011;						// type - 0x78 -> start S0 0xFB
								xgmii_ctrl0 <= 1'b1;
					end	
					else if (type_classifier_reg[7] == 1'b1) begin
								xgmii_octet0 <= 8'b11111101;						// type - 0x87 -> terminate T0 0xFD
								xgmii_ctrl0 <= 1'b1;
					end

					else if (type_classifier_reg[6:0] != 7'b0000000) begin
								xgmii_octet0 <= input_data_regs1[17:10];				// types - 0x99, 0xAA, 0xB4, 0xCC, 0xD2, OxE1, OxFF -> D0 data 

								xgmii_ctrl0 <= 1'b0;
					end
					else begin	// data			
						xgmii_octet0 <= input_data_regs1[9:2];	 
						xgmii_ctrl0 <= 1'b0;
					end
				end
			end			
	end
	
	
	// Octet 1
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet1 <= {8{1'b0}};
					xgmii_ctrl1 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
						xgmii_octet1 <= {8{1'b0}};
						xgmii_ctrl1 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14:12] != 3'b000) begin	
								xgmii_octet1 <= C1_code;						// types - 0x1E, 0x2D, 0x33 -> C1 7-bit control
								xgmii_ctrl1 <= 1'b1;
					end
					else if ((type_classifier_reg[11:8] != 4'b0000)) begin
								xgmii_octet1 <= input_data_regs1[17:10];				// types - 0x66, 0x55, 0x78, 0x4B -> D1 data 
								xgmii_ctrl1 <= 1'b0;
					end
					else if (type_classifier_reg[7] == 1'b1) begin	
								xgmii_octet1 <= C1_code;						// type - 0x87 -> C1 7-bit control
								xgmii_ctrl1 <= 1'b1;
					end
					else if (type_classifier_reg[6] == 1'b1) begin
								xgmii_octet1 <= 8'b11111101;						// type - 0x99 -> terminate T1 0xFD
								xgmii_ctrl1 <= 1'b1;
					end
					else if ((type_classifier_reg[5:0] != 6'b000000)) begin
								xgmii_octet1 <= input_data_regs1[25:18];				// types - 0xAA, 0xB4, 0xCC, 0xD2, OxE1, OxFF -> D1 data 
								xgmii_ctrl1 <= 1'b0;
					end
					else begin	// data			
								xgmii_octet1 <= input_data_regs1[17:10];	 
								xgmii_ctrl1 <= 1'b0;
					end
				end
			end			
	end
	
	// Octet 2
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet2 <= {8{1'b0}};
					xgmii_ctrl2 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet2 <= {8{1'b0}};
					xgmii_ctrl2 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14:12] != 3'b000) begin	
								xgmii_octet2 <= C2_code;						// types - 0x1E, 0x2D, 0x33 -> C2 7-bit control
								xgmii_ctrl2 <= 1'b1;
					end
					else if ((type_classifier_reg[11:8] != 4'b0000)) begin
								xgmii_octet2 <= input_data_regs1[25:18];				// types - 0x66, 0x55, 0x78, 0x4B -> D2 data 
								xgmii_ctrl2 <= 1'b0;
					end
					else if (type_classifier_reg[7:6] != 2'b00) begin	
								xgmii_octet2 <= C2_code;						// type - 0x87, 0x99 -> C2 7-bit control
								xgmii_ctrl2 <= 1'b1;
					end
					else if (type_classifier_reg[5] == 1'b1) begin
								xgmii_octet2 <= 8'b11111101;						// type - 0xAA -> terminate T2 0xFD
								xgmii_ctrl2 <= 1'b1;
					end
					else if ((type_classifier_reg[4:0] != 5'b00000)) begin
								xgmii_octet2 <= input_data_regs1[33:26];				// types - 0xB4, 0xCC, 0xD2, OxE1, OxFF -> D2 data 
								xgmii_ctrl2 <= 1'b0;
					end
					else begin	// data			
							xgmii_octet2 <= input_data_regs1[25:18];	 
							xgmii_ctrl2 <= 1'b0;
					end
				end			
			end
	end
	
	// Octet 3
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet3 <= {8{1'b0}};
					xgmii_ctrl3 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet3 <= {8{1'b0}};
					xgmii_ctrl3 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14:12] != 3'b000) begin	
								xgmii_octet3 <= C3_code;						// types - 0x1E, 0x2D, 0x33 -> C3 7-bit control
								xgmii_ctrl3 <= 1'b1;
					end
					else if ((type_classifier_reg[11:8] != 4'b0000)) begin
								xgmii_octet3 <= input_data_regs1[33:26];				// types - 0x66, 0x55, 0x78, 0x4B -> D3 data 
								xgmii_ctrl3 <= 1'b0;
					end
					else if (type_classifier_reg[7:5] != 3'b000) begin	
								xgmii_octet3 <= C3_code;						// type - 0x87, 0x99, 0xAA -> C3 7-bit control
								xgmii_ctrl3 <= 1'b1;
					end
					else if (type_classifier_reg[4] == 1'b1) begin
								xgmii_octet3 <= 8'b11111101;						// type - 0xB4 -> terminate T3 0xFD
								xgmii_ctrl3 <= 1'b1;
					end
					else if ((type_classifier_reg[3:0] != 4'b0000)) begin
								xgmii_octet3 <= input_data_regs1[41:34];				// types - 0xCC, 0xD2, OxE1, OxFF -> D3 data  
								xgmii_ctrl3 <= 1'b0;		
					end
					else begin	// data			
						xgmii_octet3 <= input_data_regs1[33:26];	 
						xgmii_ctrl3 <= 1'b0;
					end
				end			
			end
	end
	
	// Octet 4
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet4 <= {8{1'b0}};
					xgmii_ctrl4 <= 1'b0;
			end
			else begin
				 if (sync_enabled == 1'b0) begin
					xgmii_octet4 <= {8{1'b0}};
					xgmii_ctrl4 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14] == 1'b1) begin	
								xgmii_octet4 <= C4_code;						// type - 0x1E -> C4 7-bit control
								xgmii_ctrl4 <= 1'b1;
					end
					else if(((type_classifier_reg[10] == 1'b1) | (type_classifier_reg[13] == 1'b1)) & (O4_code_flag[0] == 1'b1)) begin
								xgmii_octet4 <= O4_code;						// types - 0x2D, 0x55 -> O4 4-bit control
								xgmii_ctrl4 <= 1'b1;
					end
					else if(((type_classifier_reg[10] == 1'b1) | (type_classifier_reg[13] == 1'b1)) & (O4_code_flag[1] == 1'b1)) begin
								xgmii_octet4 <= O4_code;						// types - 0x2D, 0x55 -> O4 4-bit control
								xgmii_ctrl4 <= 1'b1;
					end
					else if ((type_classifier_reg[11] == 1'b1) | (type_classifier_reg[12] == 1'b1)) begin
								xgmii_octet4 <= 8'b11111011;						// type - 0x33, 0x66 -> start S4 0xFB
								xgmii_ctrl4 <= 1'b1;
					end	
					else if (type_classifier_reg[9] == 1'b1) begin
								xgmii_octet4 <= input_data_regs1[41:34];				// type - 0x78 -> D4 data 
								xgmii_ctrl4 <= 1'b0;
					end
					else if (type_classifier_reg[8:4] != 5'b00000) begin	
								xgmii_octet4 <= C4_code;						// types - 0x4B, 0x87, 0x99, 0xAA, 0xB4 -> C4 7-bit control
								xgmii_ctrl4 <= 1'b1;
					end
					else if (type_classifier_reg[3] == 1'b1) begin
								xgmii_octet4 <= 8'b11111101;						// type - 0xCC -> terminate T4 0xFD
								xgmii_ctrl4 <= 1'b1;
					end
					else if (type_classifier_reg[2:0] != 3'b000) begin
								xgmii_octet4 <= input_data_regs1[49:42];				// types - 0xD2, OxE1, OxFF -> D4 data
								xgmii_ctrl4 <= 1'b0;
					end
					else begin	// data			
							xgmii_octet4 <= input_data_regs1[41:34];	 
							xgmii_ctrl4 <= 1'b0;
					end
				end	
			end		
	end
	
	// Octet 5
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet5 <= {8{1'b0}};
					xgmii_ctrl5 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet5 <= {8{1'b0}};
					xgmii_ctrl5 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14] == 1'b1) begin	
								xgmii_octet5 <= C5_code;						// types - 0x1E -> C5 7-bit control
								xgmii_ctrl5 <= 1'b1;
					end
					else if ((type_classifier_reg[13:9] != 5'b00000)) begin
								xgmii_octet5 <= input_data_regs1[49:42];				// types - 0x2D, 0x33, 0x66, 0x55, 0x78 -> D5 data 
								xgmii_ctrl5 <= 1'b0;
					end
					else if (type_classifier_reg[8:3] != 6'b000000) begin	
								xgmii_octet5 <= C5_code;						// types - 0x4B, 0x87, 0x99, 0xAA, OxB4, OxCC -> C5 7-bit control
								xgmii_ctrl5 <= 1'b1;
					end
					else if (type_classifier_reg[2] == 1'b1) begin
								xgmii_octet5 <= 8'b11111101;						// type - 0xD2 -> terminate T5 0xD2
								xgmii_ctrl5 <= 1'b1;
					end
					else if ((type_classifier_reg[1:0] != 2'b00)) begin
								xgmii_octet5 <= input_data_regs1[57:50];				// types - OxE1, OxFF -> D5 data  
								xgmii_ctrl5 <= 1'b0;
					end
					else begin	// data			
							xgmii_octet5 <= input_data_regs1[49:42];	 
							xgmii_ctrl5 <= 1'b0;
					end
				end
			end			
	end
	
	// Octet 6
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet6 <= {8{1'b0}};
					xgmii_ctrl6 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet6 <= {8{1'b0}};
					xgmii_ctrl6 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14] == 1'b1) begin	
								xgmii_octet6 <= C6_code;						// types - 0x1E -> C6 7-bit control
								xgmii_ctrl6 <= 1'b1;
					end
					else if ((type_classifier_reg[13:9] != 5'b00000)) begin
								xgmii_octet6 <= input_data_regs1[57:50];				// types - 0x2D, 0x33, 0x66, 0x55, 0x78 -> D6 data 
								xgmii_ctrl6 <= 1'b0;
					end
					else if (type_classifier_reg[8:2] != 7'b0000000) begin	
								xgmii_octet6 <= C6_code;						// types - 0x4B, 0x87, 0x99, 0xAA, OxB4, OxCC, 0xD2 -> C6 7-bit control
								xgmii_ctrl6 <= 1'b1;
					end
					else if (type_classifier_reg[1] == 1'b1) begin
								xgmii_octet6 <= 8'b11111101;						// type - 0xE1 -> terminate T6 0xD2
								xgmii_ctrl6 <= 1'b1;
					end
					else if (type_classifier_reg[0] == 1'b1) begin
								xgmii_octet6 <= input_data_regs1[65:58];				// types - OxFF -> D6 data  
								xgmii_ctrl6 <= 1'b0;
					end
					else  begin	// data			
							xgmii_octet6 <= input_data_regs1[57:50];	 
							xgmii_ctrl6 <= 1'b0;
					end
				end
			end			
	end
	
	// Octet 7
	always @ (posedge clock or posedge reset) begin
			if (reset == 1'b1) begin
					xgmii_octet7 <= {8{1'b0}};
					xgmii_ctrl7 <= 1'b0;
			end
			else begin
				if (sync_enabled == 1'b0) begin
					xgmii_octet7 <= {8{1'b0}};
					xgmii_ctrl7 <= 1'b0;
				end
				else begin	
					if (type_classifier_reg[14] == 1'b1) begin	
								xgmii_octet7 <= C7_code;						// types - 0x1E -> C7 7-bit control
								xgmii_ctrl7 <= 1'b1;
					end
					else if ((type_classifier_reg[13:9] != 5'b00000)) begin
								xgmii_octet7 <= input_data_regs1[65:58];				// types - 0x2D, 0x33, 0x66, 0x55, 0x78 -> D7 data 
								xgmii_ctrl7 <= 1'b0;
					end
					else if (type_classifier_reg[8:1] != 8'b00000000) begin	
								xgmii_octet7 <= C7_code;						// types - 0x4B, 0x87, 0x99, 0xAA, OxB4, OxCC, 0xD2, 0xE1 -> C7 control
								xgmii_ctrl7 <= 1'b1;
					end
					else if (type_classifier_reg[0] == 1'b1) begin
								xgmii_octet7 <= 8'b11111101;						// type - 0xFF -> terminate T7 0xD2
								xgmii_ctrl7 <= 1'b1;
					end
					else begin	// data			
							xgmii_octet7 <= input_data_regs1[65:58];	 
							xgmii_ctrl7 <= 1'b0;
					end		
				end			
			end
	end

	// --------------------------------------------------------------------------------------------------------------
	// FSM to differentiate output + error detection
	// flags of all possible type field blocks - Figure 49-7
	 // -----------------------------------------------------------------------------
	 // [14] - 0x1E, [13] - 0x2D, [12] - 0x33, [11] - 0x66 , [10] - 0x55, 
	 // [9] - 0x78, [8] - 0x4B, [7] - 0x87, [6] - 0x99, [5] - 0xAA, 
	 // [4] - 0xB4, [3] - 0xCC, [2] - 0xD2, [1] - 0xE1, [0] - 0xFF
		
	//-----Problem might be here-----
	always @ (posedge clock or posedge reset) begin
			if(reset == 1'b1) begin
				type_invalid_code <= 1'b0;
				out_type_reg <= ctrl_frame; 
				
			end
			else begin
				if(sync_enabled == 1'b0) begin
					type_invalid_code <= 1'b1;
					out_type_reg <= ctrl_frame; 
				end			
				else begin
					if ( (type_ctrl == 1'b1) & ( (type_classifier[0] == 1'b1) |  (type_classifier[1] == 1'b1) | (type_classifier[2] == 1'b1) | (type_classifier[3] == 1'b1) | (type_classifier[4] == 1'b1) | (type_classifier[5] == 1'b1) | (type_classifier[6] == 1'b1) | (type_classifier[7] == 1'b1) )) begin 
						type_invalid_code <= 1'b0;
						out_type_reg <= terminate_frame;
					end
					else if ((type_ctrl == 1'b1) & ((type_classifier[14] == 1'b1) | (type_classifier[13] == 1'b1) | (type_classifier[10] == 1'b1) | (type_classifier[8] == 1'b1))) begin
						type_invalid_code <= 1'b0;
						out_type_reg <= ctrl_frame;
					end
					else if ((type_ctrl == 1'b1) & ((type_classifier[12] == 1'b1) | (type_classifier[11] == 1'b1) | (type_classifier[9] == 1'b1) )) begin
						type_invalid_code <= 1'b0;
						out_type_reg <= start_frame;
					end	
					else if (type_data == 1'b1) begin
						type_invalid_code <= 1'b0;
						out_type_reg <= data_frame;	
					end											
				 	else begin
						out_type_reg <= error_frame;				
						type_invalid_code <= 1'b1;
					end					
				end
			end
	end
 	assign out_type = out_type_reg;
	// --------------------------------------------------------------------------------------------------------------
	
	// final assignment
	assign invalid_code = type_invalid_code;
	
	assign xgmii_in_txd = {xgmii_octet7, xgmii_octet6, xgmii_octet5, xgmii_octet4,
			       xgmii_octet3, xgmii_octet2, xgmii_octet1, xgmii_octet0};
								  
	assign xgmii_in_txc = {xgmii_ctrl7, xgmii_ctrl6, xgmii_ctrl5, xgmii_ctrl4,
			       xgmii_ctrl3, xgmii_ctrl2, xgmii_ctrl1, xgmii_ctrl0};
	 	
endmodule

  
