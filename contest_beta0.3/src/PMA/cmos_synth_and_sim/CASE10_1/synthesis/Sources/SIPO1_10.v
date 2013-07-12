// Written by Yury Audzevich
//
// Comments, suggestions for improvement and criticism welcome
// E-mail:  yury.audzevich~at~cl.cam.ac.uk
//
//
// Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
// Copyright and related rights are licensed under the Hardware License, 
// Version 2.0 (the "License"); you may not use this file except in 
// compliance with the License. You may obtain a copy of the License at
// http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
// Unless required by applicable law or agreed to in writing, software, 
// hardware and materials distributed under this License is distributed 
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//
//

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Serial-In-Parallel-Out shift register.
//
//////////////////////////////////////////////////////////////////////////////////
module SIPO1_10(
 	input CLK_IN,
	input RESET_IN,
	input SERIAL_IN,
	output DATA_USED_OUT,
	output reg [9:0] PARALLEL_OUT
);

 
// register to hold shift values.
reg [9:0] shift_reg;
reg [3:0] ctr;

assign DATA_USED_OUT = (ctr==2);

always @(posedge CLK_IN or posedge RESET_IN) begin
	if (RESET_IN) begin
         ctr <= 0;
         shift_reg <= 0;
	 PARALLEL_OUT <= 0; 
   end
   else begin
	ctr <= ctr + 1;
		
 	if(ctr == 4'd1) begin
		PARALLEL_OUT <= shift_reg;
		//shift even during the out phase
		shift_reg[9:0] <= {SERIAL_IN, shift_reg[9:1]};
	end
	else begin	
		shift_reg[9:0] <= {SERIAL_IN, shift_reg[9:1]};
	end
			
	if (ctr == 4'd9) ctr <= 0;
    end
end


endmodule
