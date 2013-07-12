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
// Dual 8b10b encoder with a simple phase compensation scheme. 
// The design requires two complementary clocks
// that are fed by an external clocking generation unit. Input data, i.e. 
// two 8-bit words, are encoded sequentially using complementary clock signals and 
// disparity information generated at every module. To compensate phase 
// difference between encoded outputs, two synchronous fifos with a simple FSM  
// are used.
//////////////////////////////////////////////////////////////////////////////////
module tx_dual_8b10b_fast
	#(
		parameter DWIDTH_WR = 8,
		parameter DWIDTH_RD = 11
	 )
   (
	 input wire clkd,
	 input wire clki,
	 input wire arst,
	 input wire din_rdy,
    input wire [(DWIDTH_WR*2)-1:0] enc_din,    
	 input wire [1:0] enc_ctrl,
	 //	
	 output reg [(2*DWIDTH_RD)-1:0] rdata,
	 output reg read
 	
	);	

 // ----- regs && wires -----
 // encoder A
 reg [DWIDTH_WR-1:0] edin_a;
 reg ectrl_a;
 reg eforced_a;
 wire [DWIDTH_RD-2:0] enc_dout_a;
 wire enc_ctrl_illeg_a;
 wire enc_dispin_a;
 wire enc_dispout_a;
  
 // encoder B
 reg [DWIDTH_WR-1:0] edin_b;
 reg ectrl_b;
 reg eforced_b;
 wire [DWIDTH_RD-2:0] enc_dout_b;
 wire enc_ctrl_illeg_b;
 wire enc_dispin_b;
 wire enc_dispout_b;
 
 // two pipeline stages for alignment
 reg [DWIDTH_RD-1:0] wdata_a;
 reg write_a;
 reg [DWIDTH_RD-1:0] wdata_a_next;
 reg write_a_next;	
 
 // two pipeline stages with registers
 reg [DWIDTH_RD-1:0] wdata_b;
 reg write_b;
 reg [DWIDTH_RD-1:0] wdata_b_next;
 reg write_b_next; 
 
  
 // fsm controls 
 reg state, next_state;

 //////////////////////////////////////////////////////////////////	
 // encs
 enc8B10B encoder8b10b_A( .clk(clkd), .arst(arst),
								  .din(edin_a),
								  .ctrl(ectrl_a),
								  //
							     .dout(enc_dout_a),
							     .ctrl_err(enc_ctrl_illeg_a),
								  //
								  .force_disp(eforced_a),
								  .disp_in(enc_dispin_a), 	
						        .disp_out(enc_dispout_a)					     
							   );

 enc8B10B encoder8b10b_B( .clk(clki), .arst(arst),
								  .din(edin_b),
								  .ctrl(ectrl_b),
								  //
								  .dout(enc_dout_b),
								  .ctrl_err(enc_ctrl_illeg_b),
								  //
							     .force_disp(eforced_b),
								  .disp_in(enc_dispin_b),
						        .disp_out(enc_dispout_b)						     
							   );

 //////////////////////////////////////////////////////////////////
 // set up the data before feeding to enc inputs
 always @ (posedge clki or posedge arst) begin
		if (arst) begin
			{edin_b, edin_a} 			<= 0;
			{ectrl_b, ectrl_a}		<= 0;
			{eforced_b, eforced_a}	<= 0;			
		end
		else begin
			if (din_rdy) begin
				{edin_b, edin_a} 			<= enc_din;
				{ectrl_b, ectrl_a}		<= enc_ctrl;
				{eforced_b, eforced_a}	<= 2'b11;					
			end
			else begin
				{edin_b, edin_a} 			<= 0;
				{ectrl_b, ectrl_a}		<= 0;
				{eforced_b, eforced_a}	<= 0;	
			end	
		end	
 end
 
 // IMPORTANT: if disparity is cross-coupled with
 // registers, output codes will be generated with
 // wrong disparity due to the offset in values 
 // generated at output and appearing at inputs within
 // the current time slot; encoder latches disparity 
 // outputs, therefore it is safe to use wires.
 assign enc_dispin_a = (arst) ? 'b0 : enc_dispout_b;
 assign enc_dispin_b = (arst) ? 'b0 : enc_dispout_a;

 
 // --- alignment of two encoded frames ----
 // Two sets of regs && a simple FSM;
 // Latch out data synchronously;
  
 // attach corresponding ctrl error information
 // #1
 always @ (posedge clkd or posedge arst)begin
    if (arst) begin
        wdata_a <= 'b0;	
		  write_a <= 'b0;
		  wdata_a_next <= 'b0;	
		  write_a_next <= 'b0;		 
    end
    else  begin
			 write_a <= 'b1;
          wdata_a <= {enc_dout_a, enc_ctrl_illeg_a};	
			 write_a_next <= write_a;
          wdata_a_next <= wdata_a;
			  	
    end
 end 

 // #2
 always @ (posedge clki or posedge arst)begin
    if (arst) begin
        wdata_b <= 'b0;
		  write_b <= 'b0;	
		  wdata_b_next <= 'b0;
		  write_b_next <= 'b0;	
    end
    else  begin
			 write_b <= 'b1;
          wdata_b <= {enc_dout_b, enc_ctrl_illeg_b};	
			 write_b_next <= write_b;
          wdata_b_next <= wdata_b;	
    end
 end 

 //// --- FSM ---
 // fsm has two states 
 // 1) wait for data, 2) read data.
  
 localparam init_state = 1'b0,
				read_state = 1'b1;  				
 // comb
 always @ (*) begin
	if(arst) begin
		next_state = init_state;
		read = 'b0;			
   end
	else begin	 
		next_state = state;			
		case(state)
			init_state : begin 
					if ((write_a_next == 1'b1) && (write_b_next == 1'b1)) begin
						next_state = read_state;
						read = 'b1;							
					end
					else begin
						next_state = init_state;
						read = 'b0;							
					end									
			end			
			read_state :  begin 					
					if ((write_a_next == 1'b0) || (write_b_next == 1'b0)) begin
						next_state = init_state;
						read = 'b0;
					end
					else begin
						next_state = read_state;
						read = 'b1;
					end 							
			end							
		endcase	
	end 
 end	

 // seq 
 always @ (posedge clkd or posedge arst) begin
		if (arst) 
			state <= init_state;
		else 
			state <= next_state;
 end


 // --- Latch out data ---   
 always @(posedge clkd or posedge arst) begin
        if (arst) begin
            rdata <= 'b0;
	end
	else begin
	    rdata <= (read) ? {wdata_b_next, wdata_a_next} : 'b0;	
	end
 end	

endmodule
