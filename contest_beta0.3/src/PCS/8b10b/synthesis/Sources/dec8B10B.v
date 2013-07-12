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
// Description: 
// 8B10B decoding is implemented using the details of original
// Widmer and Franaszek IBM paper, U.S. Patent #4,486,739 and 
// Chuck Benz's 8B10B decoder implementation (http://asics.chuckbenz.com/). 
// Figures mentioned in this file can be found in the original Widmer's paper. 
// In addition, the scheme has been modified to operate with forced input disparity;
// Irregular code and output running disparity detection logic is based on the  
// Chuck Benz's design suggestions.
///////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

module dec8B10B(

	input wire clk,
	input wire arst,
	input wire [9:0] din,
	input wire disp_in,
	input wire force_disp,
		
	output wire [7:0] dout,
	output wire cout,
	output reg disp_out,
	output reg disparity_err
	);
	
	//combinatorial logic
	wire AI, BI, CI, DI, EI;
	wire II, FI, GI, HI, JI;
	wire AInBI, CInDI, EIeII;
	wire P22, P13, P31;
	
	wire XA, XB, XC, XD;
	wire XE, XF, XG, XH, XK;
	
	wire OR561, OR562, OR563, OR564;
	wire OR565, OR566, OR567;
	wire OR341, OR342, OR343, OR344;
	
	// disparity classification and control
	wire DISPARITY6p, DISPARITY6n, DISPARITY4p, DISPARITY4n;
   wire derr1,derr2,derr3,derr4,derr5,derr6,derr7,derr8;
	wire derr1_8;
	wire disp_in_current;
		
	// output registers
	reg KO;
	reg AO, BO, CO, DO, EO;
	reg FO, GO, HO;	
	
	

	////////////////////////////////////////////////////////
	// The first bit that arrives to the serial interface is J bit, the last one is A bit
	assign {AI, BI, CI, DI, EI, II, FI, GI, HI, JI} = din[9:0];
	
	//////////////////////////////////////////////////////// 	
	// Figure 10, patent - decoding functions
	assign AInBI = (AI ^ BI); 		
	assign CInDI = (CI ^ DI);
	assign EIeII = (EI ~^ II);		
	// classification
	assign P22 = (AI & BI & !CI & !DI) | (CI & DI & !AI & !BI) | (AInBI & CInDI);
	assign P13 = (AInBI & !CI & !DI) | (CInDI & !AI & !BI);
	assign P31 = (AInBI & CI & DI) | (CInDI & AI & BI);
	
	////////////////////////////////////////////////////////
	// Figure 11, patent. K input before the FF
	assign XK = (CI & DI & EI & II) | (!CI & !DI & !EI & !II) |
				   (P13 & !EI & II & GI & HI & JI ) | (P31 & EI & !II & !GI & !HI & !JI);
		 
   ////////////////////////////////////////////////////////	
	//	Figure 12, patent. 5B6B decoder
		
	//	First set of ORs
	assign OR561 = (P22 & !AI & !CI & EIeII) | (P13 & !EI);
	assign OR562 = (AI & BI & EI & II) | (P31 & II) | (!CI & !DI & !EI & !II); 
	assign OR563 = (P31 & II) | (P22 & BI & CI & EIeII) | (P13 & DI & EI & II);
	assign OR564 = (P22 & AI & CI & EIeII) | (P13 & !EI);
	assign OR565 = (P13 & !EI) | (!CI & !DI & !EI & !II) | (!AI & !BI & !EI & !II);
	assign OR566 = (P22 & !AI & !CI & EIeII) | (P13 & !II);
	assign OR567 = (P13 & DI & EI & II) | (P22 & !BI & !CI & EIeII);
	
	//	Second set of ORs - wires A-E before Exclusive OR
	assign XA = OR567 | OR561 | OR562;
	assign XB = OR562 | OR564 | OR563;
	assign XC = OR563 | OR561 | OR565;
	assign XD = OR562 | OR564 | OR567;
	assign XE = OR566 | OR565 | OR567;
	
	//	Figure 13, patent. 3B4B decoder
	//	wires before FFs and XORs
	
	//	First set of ORs
	assign OR341 = (GI & HI & JI) | (FI & HI & JI) | (!(HI & JI) & !(!HI & !JI) & (!CI & !DI & !EI & !II));
	assign OR342 = (FI & GI & JI) | (!FI & !GI & !HI) | (!FI & !GI & HI & JI);
	assign OR343 = (!FI & !HI & !JI) | (!(HI & JI) & !(!HI & !JI) & (!CI & !DI & !EI & !II)) | (!GI & !HI & !JI);
	assign OR344 = (!GI & !HI & !JI) | (FI & HI & JI) | (!(HI & JI) & !(!HI & !JI) & (!CI & !DI & !EI & !II));	
	
	//	Second set of ORs
	assign XF = OR341 | OR342;
	assign XG = OR342 | OR343;
	assign XH = OR342 | OR344;
			
	////////////////////////////////////////////////////////	
	//	Decoding  A - H (LSB - MSB) and K 
	// latch out	
	always @ (posedge clk or posedge arst) begin
		if (arst) begin
					AO <= 0;
					BO <= 0;
					CO <= 0;
					DO <= 0;
					EO <= 0;
					FO <= 0;
					GO <= 0;
					HO <= 0;	
					KO <= 0;
					
		end
		else begin
					AO <= (XA ^ AI);
					BO <= (XB ^ BI);
					CO <= (XC ^ CI);
					DO <= (XD ^ DI);
					EO <= (XE ^ EI);
					FO <= (XF ^ FI);
					GO <= (XG ^ GI);
					HO <= (XH ^ HI);
					KO <= XK;
		end	
	end
	
	////////////////////////////////////////////////////////
	// current disparity if force_disp is asserted
	assign disp_in_current = (force_disp) ? disp_in : disp_out;
	
	// Disparity control (cont.), sequential logic  
	wire FIeGI 	 = (FI & GI) | (!FI & !GI) ;
   wire HIeJI 	 = (HI & JI) | (!HI & !JI) ;
	
	wire fghjP13 = (!FIeGI & !HI & !JI) | ( !HIeJI & !FI & !GI) ;
	wire fghjP31 = ((!FIeGI) & HI & JI) | ( !HIeJI  & FI & GI) ;	
	wire fghj22  = (FI & GI  & !HI & !JI) | (!FI & !GI &  HI & JI) | (!FIeGI & !HIeJI) ;
	
	// use internal disparity if not forced
	wire disp6a = (P31 | (P22 & disp_in_current)); 
   wire disp6a2 = (P31 & disp_in_current);  
   wire disp6a0 = (P13 & !disp_in_current); 
	wire disp6b = (((EI & II & ! disp6a0) | (disp6a & (EI | II)) | disp6a2 |
						(EI & II & DI)) & (EI | II | DI)) ;
	  
   ////////////////////////////////////////////////////////
   // Disparity for 6B and 4B codes  
   assign DISPARITY6p = (P31 & (EI | II)) | (P22 & EI & II) ;   
   assign DISPARITY6n = (P13 & ! (EI & II)) | (P22 & !EI & !II);
   assign DISPARITY4p = fghjP31 ;
   assign DISPARITY4n = fghjP13 ;

   // disparity errors	  
   assign derr1 = ((disp_in_current & DISPARITY6p) | (DISPARITY6n & !disp_in_current));   								
   assign derr2 = ((disp_in_current & !DISPARITY6n & FI & GI));   								
   assign derr3 = ((disp_in_current & AI & BI & CI));   								
   assign derr4 = (disp_in_current & !DISPARITY6n & DISPARITY4p);  								
   assign derr5 = (!disp_in_current & !DISPARITY6p & !FI & !GI);   								
   assign derr6 = (!disp_in_current & !AI & !BI & !CI);   								
   assign derr7 = (!disp_in_current & !DISPARITY6p & DISPARITY4n);   								
   assign derr8 = (DISPARITY6p & DISPARITY4p) | (DISPARITY6n & DISPARITY4n);   
   // any errors?
   assign derr1_8 = derr1 | derr2 | derr3 | derr4 |  derr5 | derr6 | derr7 | derr8;
   
      
	// latch out disparity related signals
	always @ (posedge clk or posedge arst) begin
		if(arst) begin
			disp_out <= 0;
			disparity_err <= 1;         	
		end
		else begin
			disp_out <= (fghjP31 | (disp6b & fghj22) | (HI & JI)) & (HI | JI) ;
			disparity_err <= derr1_8;
		end
	end
  	
	////////////////////////////////////////////////////////
	// FINAL ASSIGNMENT
	////////////////////////////////////////////////////////
	//data out
	assign dout = {HO, GO, FO, EO, DO, CO, BO, AO};
	
	//ctrl out					
	assign cout = KO;
	
		
endmodule

