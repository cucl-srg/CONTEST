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
// Dual 8b10b decoder with a simple phase compensation scheme. 
// The design requires two complementary clocks
// that are fed by an external clocking generation unit. Input data, i.e. 
// two 8-bit words, are decoded sequentially using complementary clock signals and 
// disparity information generated at every module. To compensate phase 
// difference between decoded outputs, two synchronous fifos with a simple FSM  
// are used.
//////////////////////////////////////////////////////////////////////////////////
module rx_dual_8b10b_fast
 	#(
		parameter DWIDTH_RD = 8,
		parameter DWIDTH_WR = 10
	 )
   (
	 input wire clkd,
	 input wire clki,
	 input wire arst,
	 input wire din_rdy,	 
	 input wire [(DWIDTH_WR*2)-1:0] dec_din,    
	 //
	 output reg [(DWIDTH_RD+2)*2-1:0] rdata,
	 output reg read    
	);	

 // ---- regs && wires -----
 // decoder A
 reg [DWIDTH_WR-1:0] ddin_a;
 reg dforced_a;
 wire [DWIDTH_RD-1:0] dec_dout_a;
 wire dec_dctrl_a;
 wire dec_disp_illeg_a;
 wire dec_dispin_a;
 wire dec_dispout_a;

 // decoder B
 reg [DWIDTH_WR-1:0] ddin_b;
 reg dforced_b;
 wire [DWIDTH_RD-1:0] dec_dout_b;
 wire dec_dctrl_b;
 wire dec_disp_illeg_b;
 wire dec_dispin_b;
 wire dec_dispout_b;
 
 // registers for data alignment
 // a - 2 pipeline stages
 reg [DWIDTH_RD+1:0] wdata_a;
 reg write_a; 
 reg [DWIDTH_RD+1:0] wdata_a_next;
 reg write_a_next; 
 // b 
 reg [DWIDTH_RD+1:0] wdata_b;
 reg write_b;
 reg [DWIDTH_RD+1:0] wdata_b_next;
 reg write_b_next; 


 // synch fsm
 reg state, next_state;
 
//////////////////////////////////////////////////////////////////	
 dec8B10B decoder8b10b_A( .clk(clkd), .arst(arst),
								  .din(ddin_a),								  
								  //
							     .dout(dec_dout_a),
								  .cout(dec_dctrl_a),
							     .disparity_err(dec_disp_illeg_a),
								  //
								  .force_disp(dforced_a),
								  .disp_in(dec_dispin_a), 	
						        .disp_out(dec_dispout_a)					     
							   );
								

 dec8B10B decoder8b10b_B( .clk(clki), .arst(arst),
								  .din(ddin_b),								  
								  //
								  .dout(dec_dout_b),
								  .cout(dec_dctrl_b),
								  .disparity_err(dec_disp_illeg_b),
								  //
							     .force_disp(dforced_b),
								  .disp_in(dec_dispin_b),
						        .disp_out(dec_dispout_b)						     
							   );
 
 //############################################################
 // set up the data before feeding to enc inputs
 always @ (posedge clki or posedge arst) begin
		if (arst) begin
			{ddin_b, ddin_a} 			<= 0;
			{dforced_b, dforced_a}	<= 0;			
		end
		else begin
			if (din_rdy) begin
				{ddin_b, ddin_a} 			<= dec_din;				
				{dforced_b, dforced_a}	<= 2'b11;					
			end
			else begin
				{ddin_b, ddin_a} 			<= 0;				
				{dforced_b, dforced_a}	<= 0;	
			end	
		end	
 end
 
 // IMPORTANT: if disparity is cross-coupled with
 // registers, output codes will be generated with
 // wrong disparity; encoder latches disparity outputs, 
 // safe to use wires.
 assign dec_dispin_a = (arst) ? 'b0 : dec_dispout_b;
 assign dec_dispin_b = (arst) ? 'b0 : dec_dispout_a;
 
 // --- align ofset frames ----
 // Two sets of regs  and a simple FSM;
 // Latch out data synchronously;
 
 // include ctrl code type, data itself and the ctrl error information
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
          wdata_a <= {dec_dctrl_a, dec_dout_a, dec_disp_illeg_a};	
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
          wdata_b <= {dec_dctrl_b, dec_dout_b, dec_disp_illeg_b};	
			 write_b_next <= write_b;
          wdata_b_next <= wdata_b;	
    end
 end 

 //// Phase alignment FSM
 //// 1) wait for sufficient data, 2) drain fifo data
 localparam init_state = 1'b0,
				read_state = 1'b1; 
	
 // fsm comb
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

 // fsm seq 
 always @ (posedge clkd or posedge arst) begin
		if (arst) 
			state <= init_state;
		else 
			state <= next_state;
 end


 // --- Latch out aligned data ---   
 always @(posedge clkd or posedge arst) begin
        if (arst) begin
            rdata <= 'b0;
	end
	else begin
	    rdata <= (read) ? {wdata_b_next, wdata_a_next} : 'b0;
	end
 end	

endmodule
