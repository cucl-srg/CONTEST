`timescale 1ps / 1ps
//  Written by Andrew West, Yury Audzevich
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
// Description: 
// AFW - derive the 10.3125GHz /64 and /66 clocks from common source
//     - use a latch-based clock gate to make the /66 clock inactive 1 cycle out of 33.
//     - this matches how it would typically be implemented
// YA  - no gearbox modules are supplied with the first release. 
//////////////////////////////////////////////////////////////////////////////////
module tb_pcs();

//----------------------------------------------
// TRANSMITTER 
// 72b	    72b    66b	   66b 	      64b
// AFIFO -> ENC	-> SCR	-> GEARTX -> (SER)
// clk 0&1  clk 1  clk 1   clk 1&2	  
//----------------------------------------------
// RECEIVER
// 64b	    64b       66b     72b      72b
// (DES) -> GEARRX -> DSCR -> DEC  ->  AFIFO 
// (PLL)    clk 2&1   clk 1   clk 1    clk 1&0
//----------------------------------------------

/// --- params ----
parameter AFIFO_WIDTH = 72;
parameter EDATA_WIDTH = 64;
parameter ECTRL_WIDTH = 8;			 	
parameter GEAR1_WIDTH = 66;
parameter GEAR2_WIDTH = 64;
parameter SYNC_HDR_WIDTH = 2; 

/// --- internal regs && wires ----
 // afifo tx side
 reg [AFIFO_WIDTH-1:0]  infifo_din;
 reg infifo_write;
 reg infifo_read;
 wire [AFIFO_WIDTH-1:0] infifo_dout;
 wire infifo_empty;
 wire infifo_aempty;
 wire infifo_full;
 wire infifo_afull; 

 // encoding 
 reg [EDATA_WIDTH-1:0] 	enc_din;
 reg [ECTRL_WIDTH-1:0] 	enc_ctrlin;
 wire [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] enc_dout;
 wire enc_illegal_out;

 // scrambling
 reg [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] scr_din;
 reg 	scr_enbl;			
 reg 	scr_bypass;
 wire [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] scr_dout;	
 
 // --- ideal interconnect 
 
 // descrambler
 reg [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] descr_din;
 reg  descr_din_word_locked;
 reg 	descr_enbl;		
 reg 	descr_bypass;
 wire [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] desc_dout;
 wire	descr_dout_word_locked;
 
 // decoding
 reg [EDATA_WIDTH+SYNC_HDR_WIDTH-1:0] dec_din;  
 reg dec_in_sync;
 wire [EDATA_WIDTH-1:0]	dec_dout;
 wire [ECTRL_WIDTH-1:0] dec_ctrlout;
 wire dec_code_invalid;
  
 // afifo rx side
 reg [AFIFO_WIDTH-1:0]  outfifo_din;
 reg outfifo_write;
 reg outfifo_read;
 wire [AFIFO_WIDTH-1:0] outfifo_dout;
 wire outfifo_empty;
 wire outfifo_aempty;
 wire outfifo_full;
 wire outfifo_afull;


/// clocks && resets
reg clk10g;
reg clk161;
wire clk156;
reg arst161;
reg arst156;

// core
wire clk156_core;
reg reset_core_tx;
reg reset_core_rx;

/// ---- input pattern ----
 reg [71:0] data_custom [0:12434];  //custom_input with 20 back-to-back packets
 reg [13:0] i_cntr;					 	//14-bit counter

 // --- dump outputs into a file if needed
 integer dump_data;	
 reg dump_into_file;
 
 //////////////////////////////////////////////////////////////////////////////////
 // I/O port matching
 
 // Asynch. FIFO tx side -- connect to outside world 
 small_async_fifo afifo_tx (	.wclk(clk156_core), .wrst_n(~reset_core_tx),
			    	.wdata(infifo_din),
			    	.winc(infifo_write),
			    	.wfull(infifo_full),
			    	.w_almost_full(infifo_afull),
			    	.rclk(clk156), .rrst_n(~arst156),
			    	.rdata(infifo_dout),
			    	.rinc(infifo_read),
			    	.rempty(infifo_empty),
			    	.r_almost_empty(infifo_aempty)	  
			   ); 

 // 64b66b encoding									 
 encoder_64B66B encode_words(	.xgmii_in_txd(enc_din),
				.xgmii_in_txc(enc_ctrlin),
				.out_txd(enc_dout),
				.out_invalid(enc_illegal_out),
				.reset(arst156), 
				.clock(clk156)
			   );

 // parallel scrambling 
 scrambler_parallel scramble(	.data_in(scr_din),
				.dataout(scr_dout),
				.scram_enable(scr_enbl),
				.bypass_enable(scr_bypass),
				.reset(arst156),
				.clock(clk156)
			    );
									 
 /// ---- ideal interconnect ----
 

 //parallel descrambling
 descrambler_parallel descramble(.datain(descr_din),
				 .bypass_enable(descr_bypass),
				 .descram_enable(descr_enbl),
				 .dataout(desc_dout),
				 .din_synched(descr_din_word_locked),
				 .dout_synched(descr_dout_word_locked),											
				 .reset(arst156),
				 .clock(clk156)
				);
 
 // 64b66b decoding											
 decoder_64B66B decode_words(	.gbaser_txd(dec_din),
				.xgmii_in_txd(dec_dout),
				.xgmii_in_txc(dec_ctrlout),
				.invalid_code(dec_code_invalid),
				.sync_enabled(dec_in_sync),
				.reset(arst156),
				.clock(clk156)		
			   );
 

 
 // Asynch. FIFO rx side -- connect to outside world 
 small_async_fifo afifo_rx (.wclk(clk156), .wrst_n(~arst156),
			    .wdata(outfifo_din),
			    .winc(outfifo_write),
			    .wfull(outfifo_full),
			    .w_almost_full(outfifo_afull),
			    .rclk(clk156_core), .rrst_n(~reset_core_rx),
			    .rdata(outfifo_dout),
			    .rinc(outfifo_read),
			    .rempty(outfifo_empty),
			    .r_almost_empty(outfifo_aempty)	  
			  ); 
 //////////////////////////////////////////////////////////////////////////////////									 
 // dump switching activity into a *.vcd file for PrimeTimePX power analysis		
 initial begin
 	#40000;  //( or whatever time is required for the reset to finish)
  	$fdumpfile("afifo_tx.vcd");
  	$fdumpvars(0, afifo_tx,"afifo_tx.vcd"); 	
	$fdumpfile("encode_words.vcd");
  	$fdumpvars(0, encode_words,"encode_words.vcd"); 
	$fdumpfile("scramble.vcd");
  	$fdumpvars(0, scramble,"scramble.vcd");   
	// dump ON  	
	$fdumpon("afifo_tx.vcd");
	$fdumpon("encode_words.vcd");
	$fdumpon("scramble.vcd");
  	#50000000  // (or suitable run time)
	// dump OFF 	
	$fdumpoff("afifo_tx.vcd");
	$fdumpoff("encode_words.vcd");
	$fdumpoff("scramble.vcd");
	$finish;
 end

////////////////////////////////////////////////////////////////////////////////////////

// 10.3125G line rate
initial begin: clkgen_10g
  clk10g = 1'b0;
  forever #48.4848 clk10g = ~clk10g;
end
 
// Divide line rate by 64
initial begin: clkgen_161
  clk161 = 1'b0;
  forever begin
    repeat(32) begin
      @(posedge clk10g);
    end
    clk161 = ~clk161;
  end
end
 
 
// Count edges on clk161 (designed to be synthesisable)
reg [5:0] pulsectr156;
reg clock_on156;
always @(posedge clk161 or posedge arst161) begin
  if (arst161) begin
    pulsectr156 <= 6'b0;
    clock_on156 <= 1'b1;
  end
  else begin
    if(pulsectr156 == 6'd32) begin
      pulsectr156 <= 5'b0;
      clock_on156 <= 1'b0;
    end
    else begin
      pulsectr156 <= pulsectr156 + 6'd1;
      clock_on156 <= 1'b1;
    end
  end
end
 
// Clockgate
// Gating value is only updated when clock is low, avoids duty cycle degradation
// This would map to a single integrated-clockgating-cell in implementation
reg latch_en156;
always @(clock_on156 or clk161) begin
  if (clk161==1'b0) begin
    latch_en156 = clock_on156;
  end
end
// derived 156.25MHz clock
assign clk156 = clk161 && latch_en156;

// core 156 clock, same as clk156
assign clk156_core = clk156;  

initial begin
      arst156 = 1;
      arst161 = 1;
		 
      reset_core_tx = 1;
      reset_core_rx = 1;
      #40000 
      arst156 = 0; 	
      arst161 = 0;
		 
      reset_core_tx = 0;
      #40000
      reset_core_rx = 0;	
end


// ---------------- DATA INPUTS ------------------
 // Custom input patterns from a reference file
 // custom file contains 64 data and 8 control bits
 // input to asynch fifo
 always @ (posedge clk156_core or posedge reset_core_tx) begin
 	if (reset_core_tx) begin
 		infifo_write  = 'b0;
 		infifo_din = 'b0; 		
 		i_cntr		= 'b0;				
 	end	
 	else begin
 		infifo_write  = 'b1;		
		infifo_din = data_custom[i_cntr];		
			
		if (i_cntr == 'd12433) i_cntr = 'h0;
		i_cntr = i_cntr + 1'b1;				
	end 
 end
  
 // input of encoder - pcs side
 always @ (posedge clk156 or posedge arst156) begin
 	if (arst156) begin
  		enc_din = 'b0;
 		enc_ctrlin = 'b0;
		// enable read from afifo
		infifo_read = 'b0;	
 	end	
 	else begin
		if (infifo_afull) begin
		   infifo_read = 'b1;
			enc_ctrlin	= infifo_dout[7:0];
			enc_din = infifo_dout[71:8];		
		end	
	end 
 end
 
 // scrambler inputs 
always @ (posedge clk156 or posedge arst156) begin
 	if (arst156) begin
			scr_din = 'b0;
			scr_enbl = 'b0;
			scr_bypass = 'b0;
	end
	else begin
		  if (~enc_illegal_out) begin
				scr_din = enc_dout;
				scr_enbl = 'b1;
				scr_bypass = 'b0;
		  end
	end
end

/////////// -------------- inteconnect ----
  
 // descrambling 
 always @ (posedge clk156 or posedge arst156) begin
 	if (arst156) begin
			descr_din = 'b0;
			descr_enbl = 'b0;
			descr_bypass = 'b0;
			descr_din_word_locked = 'b0;
	end
	else begin
			descr_din_word_locked = 1'b1;
			descr_din = scr_dout;
			descr_enbl = 'b1;
			descr_bypass = 'b0;				
	end
 end											
											
 
 // input of decoder && Output AFIFO -- pcs && rx core sides
 always @ (posedge clk156 or posedge arst156) begin
	if (arst156) begin
			dec_din = 'b0;  
			dec_in_sync = 'b0;
			// out fifo
			outfifo_din = 'b0;
			outfifo_write = 'b0;
	end
	else begin
			// --- debug only ---
			dec_din = desc_dout;  
			dec_in_sync = descr_dout_word_locked;
			// output fifo
			if (~dec_code_invalid && dec_in_sync) begin
				outfifo_din = {dec_dout, dec_ctrlout};
				outfifo_write = 'b1;
			end
	end
 end
 
  // input of decoder && Output AFIFO -- pcs && rx core sides
 always @ (posedge clk156 or posedge arst156) begin
	if (arst156) begin
			outfifo_read = 1'b0;
	end
	else begin			
			if (outfifo_afull) outfifo_read = 1'b1;	
	end
 end
 
 
  /// dump data into file procedure
 /*	always @ (posedge clk or posedge arst) begin
			if(!arst && dump_data) 
				$fwrite(dump_data,"%b\n",scr_data_output);		
		end
 */	
  
 // --- Init main parameters, read custom patterns ------ 
 initial begin
		//resets go here		
			
		i_cntr = 14'b0; 
		
		// idle pattern - input/idle_c_64B66B.txt
		// data pattern - input/test_c_64B66B.txt	
		$readmemb("./Sources/input_pattern/test_c_64B66B.txt", data_custom);
		
		/////////////////////////////////////////////////
		// dump outputs into file				
		dump_into_file = 1'b0;		
		if (dump_into_file)  dump_data = $fopen("dump_data.txt","w");
		
		/////////////////////////////////////////////////

		///resets go here
		
		// set time of simulation
		#50000000
		
		// close the file
		if(dump_into_file) $fclose(dump_data);	
		
		// finish simulation	
		$finish;	
 	
 end 


endmodule
