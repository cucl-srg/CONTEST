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

//////////////////////////////////////////////////////////////////////////////////
// Test of a single-lane 8b10b-based physical coding scheme.
// Can be used a building block for single-lane XAUI PCS implementation. 
//////////////////////////////////////////////////////////////////////////////////
module testbench8B10B();

////// ----- pcs modules -------
//input afifo - interface to tx core 
reg [17:0] infifo_din;
reg infifo_write;
wire [17:0] infifo_dout;   
reg infifo_read;
//
wire infifo_empty;
wire infifo_full;
wire infifo_aempty;
wire infifo_afull;

//output afifo -- interface to rx core 
reg [17:0] outfifo_din;
reg outfifo_write;
wire [17:0] outfifo_dout;   
reg outfifo_read;
// 
wire outfifo_empty;
wire outfifo_full;
wire outfifo_aempty;
wire outfifo_afull;

//input pcs tx -- encoding 
reg [15:0] enc_in_data;
reg [1:0]  enc_in_ctrl;
reg enc_data_ready;
wire [19:0] enc_out_data;
wire [1:0] enc_out_err;
wire enc_out_ready;

// input pcs rx -- alignment circuit
reg [19:0] align_in_data;
reg align_enbl;
//
wire [19:0] align_out_data;
wire [1:0] align_fsm;
wire dec_aligned;

//input pcs rx -- decoding
reg dec_data_ready;
reg [19:0] dec_in_data;
wire [15:0] dec_out_data;
wire [1:0] dec_out_ctrl; 
wire [1:0] dec_disp_err;
wire dec_out_ready;


////// ----- ctrls && clocks -------
// internal clocks - pcs clocks
reg clock_pcs;
wire clk_d_pcs, clk_i_pcs;
reg clkd_enbl, clki_enbl;
reg clkd_enbl_out, clki_enbl_out;
reg reset;

// external clocks - core clocks
reg clock_core;
wire clk_core_tx, clk_core_rx;
reg clktx_enbl, clkrx_enbl;
reg clktx_enbl_out, clkrx_enbl_out;
reg reset_pcs_tx, reset_pcs_rx;

	
// custom input from file
reg [17:0] data_custom [0:49789];
reg [15:0] i_cntr;

//dump outputs to a file
// reg out_to_file_tx;
// integer encoder_tx;	
// reg out_to_file_rx;
// integer decoder_tx;

////////////////////////////////////////////////////////////////////////////////////////	
// I/O mapping 
small_async_fifo afifo_in  (.winc(infifo_write), .wclk(clk_core_tx), .wrst_n(~reset_pcs_tx),
									 .wdata(infifo_din),
									 .wfull(infifo_full),
									 .w_almost_full(infifo_afull),
									 .rempty(infifo_empty),
									 .r_almost_empty(infifo_aempty),	
									 //##
									 .rinc(infifo_read), .rclk(clk_i_pcs), .rrst_n(~reset),
									 .rdata(infifo_dout)									   
									 ); 




tx_dual_8b10b_fast tx_dual_8b10b_fast(.clkd(clk_d_pcs), .clki(clk_i_pcs), .arst(reset), 
									.din_rdy(enc_data_ready),
									.enc_din(enc_in_data),    
									.enc_ctrl(enc_in_ctrl),    
									//
									.rdata({enc_out_data[19:10], enc_out_err[1], enc_out_data[9:0], enc_out_err[0]}),
									.read(enc_out_ready)								
									);	 
	 

comma_detect comma_detect (.clk(clk_i_pcs),.rst(reset),
								  .din(align_in_data),
								  .din_en(align_enbl),
								  //
								  .comma_detected(),
								  .aligned_data(align_out_data),
								  .fsm_state(align_fsm),
								  .align_acquired(dec_aligned)
								 );



rx_dual_8b10b_fast rx_dual_8b10b_fast(.clkd(clk_d_pcs), .clki(clk_i_pcs), .arst(reset), 
									.din_rdy(dec_data_ready),
									.dec_din(dec_in_data),    
									//
									.rdata({dec_out_ctrl[1], dec_out_data[15:8], dec_disp_err[1], dec_out_ctrl[0], dec_out_data[7:0], dec_disp_err[0]}),
									.read(dec_out_ready)								
									);

									
small_async_fifo afifo_out (.winc(outfifo_write), .wclk(clk_i_pcs), .wrst_n(~reset),
									 .wdata(outfifo_din),
									 .wfull(outfifo_full),
									 .w_almost_full(outfifo_afull),
									 .rempty(outfifo_empty),
									 .r_almost_empty(outfifo_aempty),	
									 //##
									 .rinc(outfifo_read), .rclk(clk_core_rx), .rrst_n(~reset_pcs_rx),
									 .rdata(outfifo_dout)									   
									 ); 								
	   	
	 
////////////////////////////////////////////////////////////////////////////////////////	
// dump switching activity into a *.vcd file for PrimeTimePX power analysis		
initial begin
 	#40;  //( or whatever time is required for the reset to finish)
  	$fdumpfile("afifo_in.vcd");
  	$fdumpvars(0, afifo_in,"afifo_in.vcd"); 	
	$fdumpfile("tx_dual_8b10b_fast.vcd");
  	$fdumpvars(0, tx_dual_8b10b_fast,"tx_dual_8b10b_fast.vcd");   
	// dump ON  	
	$fdumpon("afifo_in.vcd");
	$fdumpon("tx_dual_8b10b_fast.vcd");
  	#50000  // (or suitable run time)
	// dump OFF
	$fdumpoff("afifo_in.vcd");
	$fdumpoff("tx_dual_8b10b_fast.vcd");
	$finish;
 end

////////////////////////////////////////////////////////////////////////////////////////	 
	
 //// --- clock generation ---
 // real system should supply these appropriately
 initial begin
   //pcs clocks
	clock_pcs = 0;
	forever #0.8 clock_pcs = ~clock_pcs;
 end

 initial begin 
	//core clocks
	clock_core = 0;
	forever #0.8 clock_core = ~clock_core;
 end

 
 // -------- all derived clocks with clock gating -------
 // glitch free clk gating
 // #1 - pcs clock - direct
 always @ (clkd_enbl or clock_pcs) begin
        if (!clock_pcs) 
				clkd_enbl_out = clkd_enbl; // build latch
 end 
 assign clk_d_pcs = clkd_enbl_out & (~clock_pcs); 
 
 // #2 - pcs clock - inverted
 always @ (clki_enbl or clock_pcs) begin
        if (!clock_pcs) 
				clki_enbl_out = clki_enbl; 
 end 
 assign clk_i_pcs = clki_enbl_out & clock_pcs; 

 // #3 -- core clock - tx side
 always @ (clktx_enbl or clock_core) begin
        if (!clock_core) 
				clktx_enbl_out = clktx_enbl; 
 end 
 assign clk_core_tx = clktx_enbl_out && clock_core; 

 // #4 -- core clock - rx side
 always @ (clkrx_enbl or clock_core) begin
        if (!clock_core) 
				clkrx_enbl_out = clkrx_enbl; 
 end 
 assign clk_core_rx = clkrx_enbl_out && clock_core; 

 	 
 // ------- enable clocks after resets ----
 // #1, #2
 always @ (posedge clock_pcs)begin
 	if (reset) begin
        clkd_enbl = 0;
		  clki_enbl = 0;	
	end
	else  begin
			clkd_enbl = 1;
			clki_enbl = 1;	
		end
	end 
	
 // #3 
 always @ (posedge clock_core) 
	if (reset_pcs_tx) clktx_enbl = 0;	
	else clktx_enbl = 1;	

 // #4
 always @ (posedge clock_core) 
	if (reset_pcs_rx) clkrx_enbl = 0;	
	else clkrx_enbl = 1;	 



 // ---------------- DATA INPUTS ------------------
 // Custom input patterns from a reference file
 // custom file contains 16 data and 2 control bits
 // input to asynch fifo
 always @ (posedge clk_core_tx) begin
 	if (reset_pcs_tx) begin
 		infifo_write  = 'h0;
 		infifo_din = 'h0; 		
 		i_cntr		= 'h0;				
 	end	
 	else begin
 		infifo_write  = 'h1;		
		infifo_din = data_custom[i_cntr];		
		//	
		if (i_cntr == 'd49787) i_cntr = 'h0;
		i_cntr = i_cntr + 1'b1;				
	end 
 end
  
 // input of encoder - pcs side
 always @ (posedge clk_i_pcs) begin
 	if (reset) begin
 		enc_data_ready  = 'h0;
 		enc_in_data = 'h0;
 		enc_in_ctrl = 'h0;
		// enable read from afifo
		infifo_read = 'h0;	
 	end	
 	else begin
		if (infifo_afull) begin
		   infifo_read = 'h1;
			enc_data_ready  = 'h1;		
			enc_in_ctrl	= {infifo_dout[17], infifo_dout[8]};
			enc_in_data = {infifo_dout[16:9], infifo_dout[7:0]};		
		end	
	end 
 end
	
 // Aligner: find frame boundary after serialization
 // pcs side 
 always @ (posedge clk_i_pcs) begin
	if(reset) begin 			
		align_in_data = 'b0;
		align_enbl = 'b0;	
	end	
	else begin 
		if (enc_out_ready) begin
			align_in_data = enc_out_data;
			align_enbl = 'b1;
		end			
	end	
 end	


	
	// Decoder: Assign inputs of code aligner	
	// pcs side
	always @ (posedge clk_i_pcs) begin
		if(reset) begin
			dec_in_data = 'b0;
			dec_data_ready = 'b0;	
		end	
		else begin 
			if (dec_aligned) begin
				dec_in_data = align_out_data;
				dec_data_ready = 1'b1;			
			end				
		end	
	end	
	
	// RX side pcs -- asynch fifo
	always @ (posedge clk_i_pcs) begin
		if(reset) begin
			outfifo_din = 'h0;
			outfifo_write = 'h0;
			//outfifo_read = 'h0;
		end	
		else begin 
			if (dec_data_ready) begin
					outfifo_write = 'h1;
					outfifo_din = {dec_out_ctrl[1], dec_out_data[15:8], dec_out_ctrl[0], dec_out_data[7:0]};												
			end				
		end	
	end	
	
	// TX side core -- asynch fifo
	always @ (posedge clk_core_rx) begin
		if (reset_pcs_rx) outfifo_read = 0;
		else if (outfifo_afull) outfifo_read = 1;
 end
	
	

// ----- INIT main parameters, read custom pattern ------ 
 initial begin
		reset = 1;
		reset_pcs_tx = 1;
		reset_pcs_rx = 1;
		
		
		// idle_c_8B10B_OFF_16b   test_c_8B10B_16b
		$readmemb("./Sources/input_pattern/test_c_8B10B_16b.txt", data_custom);


		// Enabling clocks and disabling reset
		#40 
		reset = 0;
		reset_pcs_tx = 0;
		#40
		reset_pcs_rx = 0;

			
			
		// set time of simulation
		#50000
		
 	   // finish simulation	
		$finish;			
 end

endmodule


