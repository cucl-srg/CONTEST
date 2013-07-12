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

////////////////////////////////////////////////////////////////////////////////////////
// Description:  
// 8B10B encoding is implemented using the details of original
// Widmer and Franaszek IBM paper, U.S. Patent #4,486,739 and 
// Chuck Benz's 8B10B encoder implementation (http://asics.chuckbenz.com/). 
// All Figures mentioned in this file can be found in the original Widmer's paper. 
// In addition, the scheme has been modified to operate with forced input disparity;
// This allows the parallel configuration of encoder blocks.  
////////////////////////////////////////////////////////////////////////////////////////

module enc8B10B(
 input  wire clk,
	 input  wire arst,
	 input  wire [7:0] din,
	 input  wire ctrl,
	 input  wire disp_in,
	 input  wire force_disp,
	
    output wire [9:0] dout,
    output reg disp_out,
    output wire ctrl_err	
	); 
   
	/// signals
	wire AI, BI, CI, DI;
	wire EI, FI, GI, HI;
	wire KI;
	wire AInBI, CInDI, L22, L40;
	wire L04, L13, L31;
	
	// combinatorial
	wire XA, XB, XC, XD, XE;
	wire XI, XF, XG, XH, XJ;
	wire DISP6;
	wire S;	
	
	//disp classification and control
	wire PD_1S6, ND_1S6, ND0S6, PD0S6;
	wire PD_1S4, ND_1S4, ND0S4, PD0S4;
	
	reg AO, BO, CO, DO, EO;
	reg IO, FO, GO, HO, JO;
	wire COMPLS6, COMPLS4;
	wire disp_in_current;	
	
	///////////////////////////////////////////////////////////////////////////////////////////
	// Figure 1, patent - input data bits a-h enter interface in parallel
	assign {HI, GI, FI, EI, DI, CI, BI, AI} = din[7:0];
	assign KI = ctrl;
	
	// check whether force_disp is asserted 
	assign disp_in_current = (force_disp) ? disp_in : disp_out;
		
	//////////////////////////////////////////////////////////////////////////////////////////
	// 5B6B classification functions - Figure 3, patent
	assign AInBI = (!AI & !BI) | (AI & BI);
	assign CInDI = (!CI & !DI) | (CI & DI);
	assign L22 = (AI & BI & !CI & !DI) | (!AI & !BI & CI & DI) | (!AInBI & !CInDI);
	assign L40 = AI & BI & CI & DI;
	assign L04 = !AI & !BI & !CI & !DI;
	assign L13 = (!AInBI & !CI & !DI) | (!CInDI & !AI & !BI);
	assign L31 = (!AInBI &  CI & DI ) | (!CInDI &  AI & BI);
	
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// Figure 7, patent - encoding bits a-i
	//	XA - XI - bits before Exclusive OR gates (E) and FFs
	// apply boolean logic rules to simplify expressions
	assign XA = AI;
	assign XB = L04 | (!L40 & BI);
	assign XC = L04 | CI | (!AI & !BI & !CI & EI & DI);
	assign XD = DI & !(AI & BI & CI);
	assign XE = (EI | L13) &  !(EI & DI & !CI & !BI & !AI);
	assign XI = (!EI & L22) | (EI & L40) | (EI & !DI & !CI & !(AI & BI))
					 | (KI & EI & DI & CI & !BI & !AI) | (EI & !DI & CI & !BI & !AI);

	//////////////////////////////////////////////////////////////////////////////////////////
	// Figure 8, patent - encoding bits f-j
	// XF - XJ bits before XORs and FFs	
	// added input disparity control
	assign S = (KI | ((disp_in_current) ? (L31 & DI & !EI) : (L13 & !DI & EI)) ) ;
	assign XF = (FI & !(S & (FI & GI & HI)) );
	assign XG = (GI | (!FI & !GI & !HI));
	assign XH = HI;
	assign XJ = ((!HI & (FI ^ GI)) | (S & (FI & GI & HI)) );
	
	
	////////////////////////////////////////////////////////////////////////////////////////
	// Disparity control - Figure 5, 5B/6B encoder disparity classifications
	assign PD_1S6 = (!L22 & !L31 & !EI) | (L13 & DI & EI);
	assign ND_1S6 = KI | (L31 & !DI & !EI) | (EI & !L22 & !L13);
	assign PD0S6 =  KI | (EI & !L22 & !L13);
	assign ND0S6 = PD_1S6;
	
	
   ////////////////////////////////////////////////////////////////////////////////////////	
	// Disparity control - Figure 5, 3B/4B encoder disparity classifications
	assign PD_1S4 = (!FI & !GI) | (KI & ((FI & !GI) | (!FI & GI)));
	assign ND_1S4 = FI & GI;
	assign PD0S4 =  FI & GI & HI;
	assign ND0S4 = !FI & !GI;
	
	////////////////////////////////////////////////////////////////////////////////////////
	// evaluate disparity for 6b and 4b encoders
	assign DISP6 = disp_in_current ^ (ND0S6 | PD0S6);

	//evaluate whether we need complementing 
	assign COMPLS4 = (PD_1S4 & !DISP6) | (ND_1S4 & DISP6);
	assign COMPLS6 = (PD_1S6 & !disp_in_current) | (ND_1S6 & disp_in_current);
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// Figure 7 and 8, latch outputs
	always @ (posedge clk or posedge arst) begin
		if (arst) begin
				disp_out <= 0;									
				AO <= 0;
				BO <= 0;
				CO <= 0;
				DO <= 0;
				EO <= 0;
				IO <= 0;
				FO <= 0;
				GO <= 0;
				HO <= 0;
				JO <= 0;
		end
		else begin
				disp_out <= DISP6 ^ (PD0S4 | ND0S4);
				AO <= (COMPLS6 ^ XA);
				BO <= (COMPLS6 ^ XB);
				CO <= (COMPLS6 ^ XC);
				DO <= (COMPLS6 ^ XD);
				EO <= (COMPLS6 ^ XE);
				IO <= (COMPLS6 ^ XI);
				FO <= (COMPLS4 ^ XF);
				GO <= (COMPLS4 ^ XG);
				HO <= (COMPLS4 ^ XH);
				JO <= (COMPLS4 ^ XJ);			
		end
	end	
	
	//////////////////////////////////////////////////////////////////////////
	// FINAL ASSIGNMENTS
	//////////////////////////////////////////////////////////////////////////
	
	// AO is the most signifficant bit, (AO - JO) TX first
	assign dout = {AO, BO, CO, DO, EO,
						IO, FO, GO, HO, JO};
		
	// ctrl may have only 12 combinations;
	// K28.0-7 have ai=bi=0, ci=di=ei=1;
	// K23,k27,k29,k30 have ei=fi=gi=hi=1,
	// bits ai,bi,ci,di are one of l31 - e.g. 3-ones and 1-zero
	// illegal control is used as illegal k or when reset is set 
	assign ctrl_err = ( KI & (AI  | BI  | !CI | !DI | !EI)
							     & (!EI | !FI | !GI | !HI | !L31));
 	
	
endmodule
