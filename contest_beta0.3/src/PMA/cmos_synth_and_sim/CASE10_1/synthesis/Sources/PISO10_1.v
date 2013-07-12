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
// Description: Parallel-In-Serial-Out shift register.
//
//////////////////////////////////////////////////////////////////////////////////
module PISO10_1(
   input CLK_IN,
   input RESET_IN,
   input [9:0] PARALLEL_IN,
   output DATA_USED_OUT,
   output SERIAL_OUT
);

   reg [3:0] ctr;
   reg [9:0] shift_register;

   // outputs
   assign DATA_USED_OUT = (ctr==2);
   assign SERIAL_OUT = shift_register[0];

   // capture / shift loop
   always @(posedge CLK_IN or posedge RESET_IN)
   begin
      if (RESET_IN)
      begin
         ctr<=0;
         shift_register<=0;
      end
      else
      begin
         ctr<=ctr+1;
         
         if (ctr == 4'd1)
					shift_register<=PARALLEL_IN;
			else 	
					shift_register<={1'b0,shift_register>>1};
			
			if (ctr == 4'd9) ctr <= 0;
			
      end
   end
endmodule
