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
// Description: Simple synchronizer design with the custom width depth.
// Min suggested pipeline depth is 2. Derived from 2-cycle pipelined synchronizer,
// Fig. 7.2, "Synchronization and arbitration in digital systems " by D. J. Kinniment.
//////////////////////////////////////////////////////////////////////////////////
module synchronizer
#(
	parameter WIDTH = 10,
	parameter DEPTH = 3
)
(
	input wire clockA,
	input wire resetA,
	input wire clockB,
	input wire resetB,
	
	input wire [WIDTH-1:0] dataA,
	output wire [WIDTH-1:0] dataB
);

////////////////////////////////////////////////
reg [WIDTH-1:0] dA;
reg [WIDTH-1:0] pipelineB [0:DEPTH-1];
////////////////////////////////////////////////


// clkA input register 
always @ (posedge clockA or posedge resetA) begin
	if (resetA) dA <= 'b0;
	else dA <= dataA;
end

// clkB pipeline
integer i; 
always @ (posedge clockB or posedge resetB) begin
	if (resetB) 	
		for (i=0; i<(DEPTH-1); i=i+1) 
			pipelineB[i] <= 'b0;
			
	else begin
		for (i=0; i<(DEPTH-1); i=i+1) begin
          pipelineB[i+1] <= pipelineB[i];
			 pipelineB[0] <= dA;
		end	
	end
end

assign dataB = pipelineB[DEPTH-1];

endmodule
