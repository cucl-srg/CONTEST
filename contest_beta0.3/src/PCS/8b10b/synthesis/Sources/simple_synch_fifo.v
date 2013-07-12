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
// Description: A simple synchronous fifo includes: 
// 1) regs as storage elements (efficient for small sFIFOs);
// 2) use of N bit binary pointers for data read/write, 
// where fifo DEPTH = 2^N and suggested MIN FIFO DEPTH is 3. 
// 3) use of a separate N+1-bit counter for the fill up process control.
//////////////////////////////////////////////////////////////////////////////////
module simple_synch_fifo
#(
 parameter WIDTH = 10,
 parameter HALF_DEPTH = 2,
 parameter DEPTH = 5 
)
(
	input wire clock,
	input wire reset,
	input wire [WIDTH-1:0] data_in,
	input wire write_en,
	input wire read_en,
	//
	output reg [WIDTH-1:0] data_out,
	output reg dout_valid,
	output reg fifo_error,
	output reg fifo_empty,
	output reg fifo_hfull,
	output reg fifo_afull,
	output reg fifo_full
 );

// standard log2 function
function integer log2;
	input integer n;
	begin
		log2 = 0;
		while(2**log2 < n) begin
			log2=log2+1;
		end
	end
endfunction

// pointer address width 
localparam ADDR_WIDTH = log2(DEPTH);
			  

// internal regs && wires
reg [ADDR_WIDTH-1:0] read_addr;
reg [ADDR_WIDTH-1:0] write_addr;
reg [ADDR_WIDTH:0] fill_counter;

// regs as storage
reg [WIDTH-1:0] storage [0:DEPTH-1];

// reset write/read address counts
wire rst_ra;
wire rst_wa;

// -----------------------------------------------------------------
// it's sufficient to have N bit pointers for 2^N DEPTH queue;
// N-bit pointers are used as a current read and write addresses;
// dedicated N+1 bit fill_counter is used for boundary conditions check; 
// reg type storage is effective only for small size FIFOs. 
// -----------------------------------------------------------------

// reset read/write address counters
assign rst_ra = (read_addr == (DEPTH-1)) ? 1'b1 : 1'b0;
assign rst_wa = (write_addr == (DEPTH-1)) ? 1'b1 : 1'b0;

// update read && write address pointers; 
// update fill-up && queue error status.
always @ (posedge clock or posedge reset) begin
	if (reset) begin
		read_addr  <= 'b0;
		write_addr <= 'b0;
		fill_counter <= 'b0;
		fifo_error <= 'b1;
	end
	else begin		
		if (read_en & write_en) begin	
				if (rst_wa) write_addr <= 'b0;
				else write_addr <= write_addr + 1'b1;

			   if (rst_ra) read_addr <= 'b0;
				else read_addr <= (fifo_empty) ? read_addr : (read_addr + 1'b1);
			
				fill_counter <= fill_counter;	
				fifo_error <= (fifo_empty) ? 1'b1 : 1'b0;
		end
		else if (~read_en & write_en) begin
				if (rst_wa) write_addr <=  'b0;
				else write_addr <= (fifo_full) ? write_addr : (write_addr + 1'b1);

				read_addr <= read_addr;	
				fill_counter <= (fifo_full) ? fill_counter : (fill_counter + 1'b1);
				fifo_error <= (fifo_full) ? 1'b1 : 1'b0;	
		end
		else if(read_en & ~write_en) begin
				write_addr <= write_addr;
			
				if (rst_ra) read_addr <= 'b0;
				else read_addr <= (fifo_empty) ? read_addr : (read_addr + 1'b1);
			
				fill_counter <= (fifo_empty) ? fill_counter : (fill_counter - 1'b1);	
				fifo_error <= (fifo_empty) ? 1'b1 : 1'b0;
		end
		else begin
				write_addr <= write_addr;
				read_addr <= read_addr;	
				fill_counter <= fill_counter;
				fifo_error <= 1'b0;	
		end		
	end	
end

// update all ctrl signals
always @ (*) begin
	if (reset) begin 
			dout_valid = 'b0;			
			fifo_empty = 'b0;
			fifo_hfull = 'b0;
			fifo_afull = 'b0;
			fifo_full = 'b0;		
	end
	else begin
		if (fill_counter == 'b0) fifo_empty = 1'b1;
		else fifo_empty = 1'b0;
		
		if (fill_counter == DEPTH) fifo_full = 1'b1;
		else fifo_full = 1'b0;
		
		if (fill_counter >= HALF_DEPTH) fifo_hfull = 1'b1;
		else fifo_hfull = 1'b0;
		
		if (fill_counter >= (DEPTH-2)) fifo_afull = 1'b1;
		else fifo_afull = 1'b0;
		
		dout_valid = (~fifo_empty) & read_en;		
	end
end

// write & read - to & from the DATA pipeline
integer i;
always @ (posedge clock or posedge reset) begin
	if (reset) begin
		data_out <= 'b0;
		for (i=0; i<=(DEPTH-1); i=i+1) begin
			 storage[i] <= 'b0;
		end			
	end
	else begin
		if (write_en) storage[write_addr] <= data_in;
		if (read_en & ~fifo_empty)  data_out <= storage[read_addr];			
	end		
end	

endmodule
 
