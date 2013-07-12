#!/usr/bin/perl -w


# Written by Andrew West
#
# Comments, suggestions for improvement and criticism welcome
# E-mail:  Andrew.West~at~cl.cam.ac.uk
#
#
# Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
# Copyright and related rights are licensed under the Hardware License, 
# Version 2.0 (the "License"); you may not use this file except in 
# compliance with the License. You may obtain a copy of the License at
# http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
# Unless required by applicable law or agreed to in writing, software, 
# hardware and materials distributed under this License is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#
#

# Digital Signal Injection
# `DSI'
#
#	Generates Spice stimulus and Verilog testbench files
#
#
# Revision History
#
# 03/09/2003	pre0.1	Started, specified core directives and commands
# 04/09/2003		Continued work on Spice backend and commands
#		pre0.2	First output for 7T stimulus accepted by Spice
#			Working to fix skew on signals
#			Adding inversion to handle unrealistic pwl
#			Realistic signals driven through inverters
# 23/09/2003	pre0.3	Fixed bug where radix-1 signals were misnamed
#			Fixed duty cycle bug
# 30/09/2003		Fixed fp error by rounding
#			Fixed long lines by fragmenting
# 01/10/2003	pre0.4	Added extra inverters to allow more accurate simulation
# 13/11/2003	pre0.5	Verilog testbench backend added, new .bench directives
#			Fixed bug for non-unity .multiplier
#			Command line modified
# 14/11/2003		Testbench mode functionality complete
# 21/01/2003	pre0.6	Fixed time ordering (rising edge of clocks updated last in testbench)
# 27/01/2012    pre0.7  Changed to use [] brackets for multibit signals in SPICE output
			

# General To Do

#	Allow changing of clkbase by updating clocks in sync
#	Allow assignment to single bits or bit ranges
#	Allow setting of clock rise and fall times and duty cycle
# [X]	Set clock start delay based on value
#	Add setup and hold modifiers to +command


##### Command line and usage information

$|=1;
$starttime=time();
$ver="pre0.7";
$url="http://www.cl.cam.ac.uk/users/afw27/dsi";
$ok=1;



my $q=0;
$ARGC=scalar(@ARGV);
if(($ARGC<2)||($ARGC>3)) {$ok=0;}
if(($ok)&&($ARGC==3)&&($ARGV[2] ne 'quiet'))
{
	$ok=0;
}
if(defined($ARGV[2])&&($ARGV[2] eq 'quiet')) {$q=1;}

if(!$ok)
{
	print STDERR "Error in command line arguments.\n";
	print STDERR "Digital Signal Injection       DSI release $ver\n";
	print STDERR "Usage: dsi.pl <DSI input file> <output prefix> [quiet]\n\n";
	print STDERR "Generates <output prefix>-stim.sp and <output prefix>-testbench.v\n\n";
	print STDERR "Example DSI input file:

# Comments must start at the beginnings of lines
* Spice-style comments are also allowed
* For data values, use \%110 as binary format, \$AF for hex, decimal is default

# default voltages
.vdd 1.800
.vss 0

# multiplier for all unqualified time values
.multiplier 1ps

# .sig <signal> [radix] [logic-0 voltage] [logic-1 voltage]
# implied radix of 1 when omitted
.sig reset
.sig data_out 32
.sig precharge 1 0 3.3
.sig sysclk

# .initial <signal> <value>
# signals default to logic 0 unless stated otherwise by initial directive

.initial data_out \$C0DEDBAD
.initial reset 1
.initial precharge 0
.initial sysclk 0

# .clock <signal> <period>
# any clocks should also be defined as signals in this file
.clock sysclk 500

# stimulus section follows
.begin
 
# use 'pre' as clock
\@pre
 
# advance five clocks
+5
 
# assign values to i and wra
i=%1100110011001100110011001100110011001100110011001100110011001100
wra=%0001
# advance time one clock
+
 
i=%0011001100110011001100110011001100110011001100110011001100110011
wra=%0010
+
i=%1010101010101010101010101010101010101010101010101010101010101010
wra=%0100
+
i=%0101010101010101010101010101010101010101010101010101010101010101
wra=%1000
+
 
i=0
wra=0
+4
 
rda=%0001 + rda=%0010 + rda=%0100 + rda=%1000 +
rda=1 +1 rda=2 +2 rda=4 +3 rda=8 +4
rda=\$1 + rda=\$2 + rda=\$4 + rda=\$8 +
rda=%0001 + rda=%0010 + rda=%0100 + rda=%1000 + rda=0

";
	exit(1);
}



##### Tiny subroutines

sub plu {if($_[0]!=1) {return "s";} else {return "";}}
sub out {if($q==0) {print STDERR @_;}}
sub caution {print STDERR @_;}
sub bail
{
	out($_[0]);
	print STDERR $_[1];
	exit(1);
}
sub spice
{
	print SPICEFILE $_[0];
}
sub bench
{
	print BENCHFILE $_[0];
}


##### File opening

$f=$ARGV[0];
$g=$ARGV[1];
out("Digital Signal Injection       DSI release $ver\n");
out("DSI: Opening input file '$f'...");

if(-z $f) {bail("failed\n","ERROR: zero-length input file.\n");}
if(!-e $f) {bail("failed\n","ERROR: input file does not exist.\n");}
open(IN,$f)|| bail("failed\n","ERROR: could not open input file.\n");
out("ok\n");
out("DSI: Opening output files '$g-stim.sp' and '$g-testbench.v'...");

open(SPICEFILE,">$g-stim.sp") || bail ("failed\n","ERROR: unable to open output file '$g-stim.sp'.\n");
open(BENCHFILE,">$g-testbench.v") || bail ("failed\n","ERROR: unable to open output file '$g-testbench.v'.\n");
out("ok\n");

$a=rindex($g,"/")+1;
if($a) {$g=substr($g,$a);}

undef $/;
$a=<IN>;
close(IN);


##### Handle CRLF line endings

$lf="\x0A";
$cr="\x0D";
$a=~s/$cr$lf/$lf/g;
$a=~s/$cr/$lf/g;

@file=split($lf,$a);


#### Definitions of hashes

$vdd_set=0;
$vdd=0;
$vddline=0;
$vss=0;
$vssline=0;
$vss_set=0;
$mult=0;
$mtxt="";
$multline=0;
undef %sigs;	# signals	key=sig, value=radix
undef %sigvdd;	# vdd		key=sig, value=vdd
undef %sigvss;	# vss		key=sig, value=vss
undef %sigint;	# state string	key=sig, value=state string
undef %clks;	# clocks	key=sig, value=period
undef %clkfire;	# fire
undef %clkdelay; # delay
undef %clkrise;
undef %clkfall;
undef %clkduty;
undef %clkl;
undef %clkh;

undef %benchsigs;
undef @benchmonitor;
undef @benchinit;
$benchend="quit";
$benchstim="";

undef %spice;	# spice string	key=sig.radix, value=spice string
undef %spicep;	# last spice	key=sig.radix, value=last logic level

####### Parse a decimal value, including non-integers

# in: string,errortxt
# returns: value or exits with error

sub parsedec
{

$value=0;
$in=$_[0];
$errtxt=$_[1];
if((!defined($in))||($in eq '')||($in!~/\A\d/))
{
	bail("","ERROR: expected decimal number in $errtxt on line $lno, received '$in'.\n");
}
if(index($in,".")==-1)
{
	if($in=~/\A(\d+)\z/)
	{
		return $1+0;
	}
	else
	{
		bail("","ERROR: expected decimal number in $errtxt on line $lno, received '$in'.\n");
	}
}
else
{
	if($in=~/\A(\d+)\.(\d+)\z/)
	{
		$value=$1+0;
		$tens=1;
		for($i=0;$i<length($2);$i++)
		{
			$tens*=10;
		}
		$value+=($2+0)/$tens;
		return $value;	# a "real" number
	}
	else
	{
		bail("","ERROR: expected decimal number in $errtxt on line $lno, received '$in'.\n");
	}
}
}

####### Parse a decimal value (plain), binary value (%101010) or hex value ($2992)

# in: string,radix,entity,errortext
# returns: value or exits with error

sub parseval
{
	$str=$_[0];
	$radix=$_[1];
	$entity=$_[2];
	$errtxt=$_[3];
	$str=~s/_//g;
	if($str=~/\A(\d+)\z/)
	{
		$pd=$1+0;
		$pb2=1;
		$pbv="";
		for($pi=0;$pi<$radix;$pi++)
		{
			$pe=$pd&$pb2;
			$pbv=(($pe)?"1":"0").$pbv;
			$pb2*=2;
		}
		if($pd>=$pb2)
		{
			caution("WARNING: initial value '$pd' too large to "
				."be expressed in $radix bit".&plu($radix)." for the signal '$entity', on line $lno.\n");
			caution("WARNING: value for '$entity' entered as ".($pd & ($pb2-1)).".\n");
		}
		#out("DSI: decimal value '$pd'=>'$pbv'.\n");
		$pd=$pbv;
	}
	else
	{
	if($str=~/\A\%([10]+)\z/)
	{
		$pd=$1;
		if(length($pd)>$radix)
		{ 
			caution("WARNING: initial value '\%$pd' too large to "
				."be expressed in $radix bit".&plu($radix)." for the signal '$entity', on line $lno.\n");
			$pd=substr($pd,-$radix);
			caution("WARNING: value for '$entity' entered as \%$pd.\n");
		}
		while(length($pd)<$radix) {$pd="0$pd";}
	}
	else
	{
	if($str=~/\A\$([A-Fa-f\d]+)\z/)
	{
		$pe=uc($1);
		$pd="";
		for($pi=0;$pi<length($pe);$pi++)
		{
			$pf=substr($pe,$pi,1);
			#out("hex $pf ->");
			$pf=ord($pf);
			if($pf<65) {$pf-=48;} else {$pf-=55;}
			#out("dec $pf.\n");
			$pd.=(($pf&8)?"1":"0").(($pf&4)?"1":"0").(($pf&2)?"1":"0").(($pf&1)?"1":"0");
		}
		if(length($pd)>$radix)
		{ 
			caution("WARNING: initial value '\%$pd' too large to "
				."be expressed in $radix bit".&plu($radix)." for the signal '$entity', on line $lno.\n");
			$pd=substr($pd,-$radix);
			caution("WARNING: value for '$entity' entered as \%$pd.\n");
		}
		while(length($pd)<$radix) {$pd="0$pd";}
	}
	else
	{
		bail("","ERROR: invalid value '$str' - expected decimal, binary(%) or hex(\$) value for signal '$entity' in "
			."$errtxt on line $lno.\n");

	}
	}
	}
	return $pd;
}



###############    HEADER SCAN

# set up Vss, Vdd, time multiplier, all signals, initial values (optional), clocks

out("DSI: Started to process input file.\n");

$endscan=0;
$stimno=0;
$lno=1;
foreach $l (@file)
{
	chomp($l);
	$a=substr($l,0,1);
	if(($a eq '#')||($a eq '*')||($endscan))
	{
		# comment or end of scan, so ignored line
	}
	else
	{
	if($a eq '.')
	{
		# we have a dot directive
		@items=split(/\s+/,substr($l,1));
	
		if($items[0] eq 'vss')
		{
			if($vss_set) {bail("","ERROR: multiple .vss directives are not allowed, lines $vssline and $lno.\n");}
			$vss=parsedec($items[1],".vss directive");
			$vss_set=1;
			$vssline=$lno;
			out("DSI: Vss set to ${vss}V.\n");
		}
		else
		{
		if($items[0] eq 'vdd')
		{
			if($vdd_set) {bail("","ERROR: multiple .vdd directives are not allowed, lines $vddline and $lno.\n");}
			$vdd=parsedec($items[1],".vdd directive");
			$vdd_set=1;
			$vddline=$lno;
			out("DSI: Vdd set to ${vdd}V.\n");
		}
		else
		 {
		if($items[0] eq 'begin')
		{
			$endscan=$lno;
			$stimno=$lno+1;
			out("DSI: Processing actual stimulus information from line $stimno onwards.\n");
		}
		else
		  {
		if($items[0] eq 'multiplier')
		{
			if($multline) {bail("","ERROR: multiple .multiplier directives are not allowed, lines $multline and $lno.\n");}
			if($items[1]=~/(\d)(|s|ms|m|us|u|ns|n|ps|p|fs|f)\z/)
			{
				$mtxt=substr($2,0,1);
				#if($mtxt eq ''){$mtxt="s";}
				$m=parsedec($`.$1,".multiplier directive");
				$multline=$lno;
				if($mtxt eq '') {$mult=$m;}
				if($mtxt eq 'm') {$mult=$m/1000;}
				if($mtxt eq 'u') {$mult=$m/1000000;}
				if($mtxt eq 'n') {$mult=$m/1000000000;}
				if($mtxt eq 'p') {$mult=$m/1000000000000;}
				if($mtxt eq 'f') {$mult=$m/1000000000000000;}
				$mtxt.="s";

				
				if($mult==0)
				{
					bail("","ERROR: .multiplier directive cannot be zero on line $lno.\n");
				}
				out("DSI: time multiplier set to ${m}$mtxt".(($mtxt eq 's')?"":" (${mult}s)").".\n");
				
			}
			else
			{
				bail("","ERROR: bad input '$items[1]' in .multipler directive on line $lno, use '.multiplier 330n', for example.\n");
			}
		}
		else
		   {
		if($items[0] eq 'sig')
		{

			# .sig <name> [radix] [logic0 voltage] [logic1 voltage]

			if($items[1]=~/\A([A-Za-z\_][A-Za-z\d\_]*)\z/)
			{
				$c=$1;
				if((!defined($items[2]))||($items[2] eq ''))
				{
					out("DSI: new signal '$c' added with implied radix of 1.\n");
					$sigs{$c}=1;
					$sigvss{$c}=-1;
					$sigvdd{$c}=-1;
				}
				else
				{
					unless(($items[2]=~/\A(\d+)\z/)&&($d=$1+0)&&($d!=0))
					{
						bail("","ERROR: illegal radix '$items[2]' for signal '$c' on line $lno.\n");
					}
					if($d>1024)
					{
						bail("","ERROR: radix '$d' too large to be sane for signal '$c' on line $lno.\n");
					}

					$sigs{$c}=$d;

					unless((!defined($items[3]))||($items[3] eq ''))
					{
						$e=parsedec($items[3],"logic-0 voltage parameter of .sig directive");

						unless((!defined($items[4]))||($items[4] eq ''))
						{
							$f=parsedec($items[4],"logic-1 voltage parameter of .sig directive");
						
							if($e>=$f) {bail("","ERROR: Logic-1 level (value read = $f) must exceed Logic-0 level "
								."(value read = $e) for signal '$c' on line $lno.\n");}

							# add sig with specified vdd and specified vss levels

							$sigvss{$c}=$e;
							$sigvdd{$c}=$f;
							out("DSI: new signal '$c' added with radix of $d, Logic-0 level of ${e}V and Logic-1 level of ${f}V.\n");

						}
						else
						{
							# add sig with specified vss level and global vdd level
							$sigvss{$c}=$e;
							$sigvdd{$c}=-1;
							out("DSI: new signal '$c' added with radix of $d, Logic-0 level of ${e}V.\n");
						}

					}
					else
					{
						# default vss and vdd levels for these signals
						# (vdd and vss may not have been defined at this point in time so
						$sigvss{$c}=-1;
						$sigvdd{$c}=-1;
						out("DSI: new signal '$c' added with radix of $d.\n");
					}


				}
				#out("DSI: new sig '$1'.\n");

			}
			else
			{
				bail("","ERROR: invalid characters in signal name '$items[1]' on line $lno.\n");
			}


		}
		else
		    {
		if($items[0] eq 'initial')
		{
			# .initial <name> <value>

			$c=$items[1];
			if(!defined($sigs{$c}))
			{
				bail("","ERROR: signal '$c' has not been defined before the .initial directive on line $lno.\n");
			}

			if(defined($sigint{$c}))
			{
				bail("","ERROR: initial value for signal '$c' has already been set before the .initial directive on line $lno.\n");
			}


			# internally store bit vectors as strings to avoid overflow for e.g. 64-bit numbers

			$sigint{$c}=parseval($items[2],$sigs{$c},$c,".initial directive");

			
			out("DSI: initial value ".(($sigs{$c}>1)?"\%":"")."$sigint{$c} for signal '$c' noted.\n");

		}
		else
		     {
		if($items[0] eq 'clock')
		{

			if($mult==0) {bail("","ERROR: .multiplier directive must precede .clock directive on line $lno.");}

			$c=$items[1];
			if(!defined($sigs{$c}))
			{
				bail("","ERROR: signal '$c' has not been defined before the .clock directive on line $lno.\n");
			}

			if($sigs{$c}!=1)
			{
				bail("","ERROR: signal '$c' should have a radix of 1 to sensibly be defined using a .clock directive on line $lno.\n");
			}

			if(defined($clks{$c}))
			{
				bail("","ERROR: clock '$c' has already been defined before the .clock directive on line $lno.\n");
			}

			unless(($items[2]=~/\A(\d+)\z/)&&($d=$1+0)&&($d!=0))
			{
				bail("","ERROR: illegal clock period '$items[2]' for signal '$c' on line $lno.\n");
			}



			out("DSI: signal '$c' is a clock with period ${d}$mtxt.\n");
			$clks{$c}=$d*$mult;
			$clkfire{$c}=$clks{$c}/2;
			
			# XXX clock defaults
			$clkrise{$c}=$clks{$c}/10;
			$clkfall{$c}=$clks{$c}/10;
			$clkduty{$c}=0.5;
			$clkh{$c}=$clkduty{$c}*$clks{$c}*(1-(($clkrise{$c}+$clkfall{$c})/$clks{$c}));
			$clkl{$c}=(1-$clkduty{$c})*$clks{$c}*(1-(($clkrise{$c}+$clkfall{$c})/$clks{$c}));
		}
		else
		      {
		if($items[0] eq 'bench_out')
		{
			shift(@items);
			#out("DSI: bench_out '".join(":",@items)."'\n");
			$it=0;
			$currentsig="";
			while(scalar(@items))
			{
				if($it==0)
				{
					if($items[0]=~/\A([A-Za-z\_][A-Za-z\d\_]*)\z/)
					{
						if(defined($sigs{$1}))
						{
							bail("","ERROR: module output '$1' for testbench on line $lno already defined as a stimulus input.\n");
						}
						else
						{
							$currentsig=$1;
							#out("ok '$1'\n");
							$it=1;
							shift(@items);
						}
					}
					else
					{
						bail("","ERROR: invalid characters in signal name '$items[0]' on line $lno.\n");
					}
				}
				else
				{
					unless(($items[0]=~/\A(\d+)\z/)&&($d=$1+0)&&($d!=0))
					{
						bail("","ERROR: illegal radix '$items[0]' for signal '$currentsig' on line $lno.\n");
					}
					$it=0;
					shift(@items);
					$benchsigs{$currentsig}=$1;
				}

			}
		}
		else
		       {
		if($items[0] eq 'bench_monitor')
		{
			shift(@items);
			$bm=join(" ",@items);
			push(@benchmonitor,$bm);
			out("DSI: bench_monitor '$bm'\n");
		}
		else
		        {
		if($items[0] eq 'bench_end')
		{
			if($items[1] eq 'quit')
			{
				$benchend=$items[1];
			}
			else
			{
				if($items[1] eq 'stop')
				{
					$benchend=$items[1];
				}
				else
				{
					if($items[1] eq 'continue')
					{
						$benchend=$items[1];
					}
					else
					{
						bail("","ERROR: invalid option '$items[1]' in .bench_end on line $lno. Valid ".
						"options are 'continue', 'stop' and 'quit'(the default).\n");
					}
				}
			}
				
			out("DSI: bench_end '$benchend'\n");
		}
		else
		         {
		if($items[0] eq 'bench_init')
		{
			shift(@items);
			$bm=join(" ",@items);
			push(@benchinit,$bm);
			out("DSI: bench_init '".join(":",@items)."'\n");		
		}
		else
		{
			bail("","ERROR: unknown directive '$l' on line $lno.\n");
			#caution("WARNING: unknown directive '$l' on line $lno.\n");

		}
                         }
                        }
		       }
		      }
		     }
		    }
		   }
		  }
		 }
		}


	}	



#	out("DSI: read line '$l'.\n");

	}
	$lno++;
}

# various sanity checks so we don't let the user abuse us to write a crazy Spice file

if($vdd_set==0) {bail("","ERROR: missing .vdd directive. Use '.vdd <voltage>' to set the overall Vdd.\n");}

if($vss_set==0) {bail("","ERROR: missing .vss directive. Use '.vss <voltage>' to set the overall Vss.\n");}

if($vss>=$vdd) {bail("","ERROR: Vdd (value read = $vdd) must exceed Vss (value read = $vss).\n");}

if($mult==0) {bail("","ERROR: missing .multiplier directive. Use '.multiplier <timescale>' to set.\n");}


####### Fill in any remaining vdd, vss and initialisation values to zero
#### Pass vss, vdd to bits of signals

foreach (sort(keys %sigs))
{
#	print "$_\n";
	if($sigvss{$_}==-1) {$sigvss{$_}=$vss;}
	if($sigvdd{$_}==-1) {$sigvdd{$_}=$vdd;}
	if(!defined($sigint{$_})) {$sigint{$_}="0"x$sigs{$_};}

	if(defined($clks{$_}))
	{
		$clkdelay{$_}=(($sigint{$_} eq '0')?(0):($clkrise{$_}+$clkl{$_}));
	}
	else
	{
		$rad=$sigs{$_};
			for($i=0;$i<$rad;$i++)
			{	
				$ind=$_.$i;
				$sigvss{$ind}=$sigvss{$_};
				$sigvdd{$ind}=$sigvdd{$_};
			}
	}
	
#	out("DSI: SIGNAL $_ has VDD $sigvdd{$_}, VSS $sigvss{$_}, INITIAL $sigint{$_}, CLOCK PERIOD $clks{$_}.\n");

}






############## STIMULUS SCAN



##### State subroutines

sub updatestate
{
# Note the current state in %sigint and keep internal spice info up to date
# Call after every command executes to make sure all transitions are handled
# Handles logic level to voltage conversion
# In the first call (thus %spicep is undef), the initial values are dumped

# Rather than noticing which bits may have changed (probably hard),
# we just check them all cheaply
# To make a Verilog testbench, we just update $benchstim when we update any signal for Spice
# This avoids confusion, by producing output that does not update any signals unless they
# have in fact changed in at least one bit.

# But all our outputs are fed through three inverters, so Spice logic levels written are inverted here


	foreach (sort(keys %sigs))
	{
		$rad=$sigs{$_};
		if(!defined($clks{$_}))
		{
			$tainted=0;
			for($i=0;$i<$rad;$i++)
			{	
                                # Jan 2012 spice radix support - afw27
                                $ind=$_."[".$i."]";

				if($rad==1){$ind=$_;}
				$prev="";
				if(defined($spicep{$ind}))
				{
					$prev=$spicep{$ind};
					$cur=substr($sigint{$_},$rad-1-$i,1);
					if($prev ne $cur)
					{
						$tainted=1;
						# simplistic bit update (bloats file size for wide signals)
				#		$benchstim.="		$_\[$i]=$cur;\n";
						$spicep{$ind}=$cur;	
						if($prev eq '0') 
						{
							# rise
							$spice{$ind}.=
							# NB intentional reversal of vss and vdd
							($t-$sigrise*6-$sigrise/2)."\n+ $sigvdd{$_} ".
							($t-$sigrise*6+$sigrise/2)." $sigvss{$_} ";
						}
						else
						{
							# fall
							$spice{$ind}.=
							# NB intentional reversal of vss and vdd
							($t-$sigrise*6-$sigfall/2)."\n+ $sigvss{$_} ".
							($t-$sigrise*6+$sigfall/2)." $sigvdd{$_} ";
						}
					}
				}
				else
				{
					# initial value, or not previously set
					$tainted=1;
					$cur=substr($sigint{$_},$rad-1-$i,1);
					$spice{$ind}.=
					# NB intentional reversal of vss and vdd
					"0 ".(($cur eq "1")?("$sigvss{$_}"):("$sigvdd{$_}"))." ";
					$spicep{$ind}=$cur;
				}

			}
			if($tainted)
			{
				$benchstim.="		$_=$sigs{$_}'b$sigint{$_};\n";
			}
		}

	}
}

sub dumpstate
{
# Return a string showing the current bit state

	$z="TIME=${t}s (".($t*($m/$mult))."${mtxt})\n";
	foreach (sort(keys %sigs))
	{
		if(defined($clks{$_}))
		{
			$z.="$_\t(clock)\n";
		}
		else
		{
			$z.="$_\t$sigint{$_}\n";
		}
	}
	return $z;
}



##### Command subroutine

sub stim
{
# input: command string
# Updates the time ($t) and the current state (%sigint)
# To handle clocks, %clkfire is used to store the deadlines

# When updatestate() is called in this routine, all state changes are echoed to 
# the internally built spice strings

	#out("DSI: executing command '$c'\n");
	$cmd=$_[0];
	$a=substr($cmd,0,1);

	if($a eq "@")
	{
		$d=substr($cmd,1);
		unless(exists($clks{$d}))
		{
			if(exists($sigs{$d}))
			{
				bail("","ERROR: signal '$d' has not been ".
	"defined with a .clock directive, so unable to use in \"\@\" command on line $lno.\n");
			}
			else
			{
				bail("","ERROR: '$d' is not a signal or a clock, ".
	"it must be defined before use in \"\@\" command on line $lno.\n");
			}
		}
		out("DSI: set clock base to '$d'.\n");
		$clkbase=$d;
		# XXX  use clock base for rise/fall estimates on the signals
		$sigrise=$clkrise{$d};
		$sigfall=$clkfall{$d};
	}
	else
	{
	if($a eq "+")
	{
		if($clkbase eq '')
		{
			bail("","ERROR: need to set clock reference with \"\@\" command "
		."before using \"+\" command on line $lno.\n");
		}

		unless($cmd=~/\A\+(|\d+)\z/)
		{
			bail("","ERROR: Illegal number of clock periods ('".
			substr($cmd,1)."') in \"+\" command on line $lno.\n");
		}
		if($1 eq '') {$cy=1;} else {$cy=$1+0;}

		out("DSI: clock jump of $cy cycle".plu($cy)." for '$clkbase'.\n");

#		foreach $dl (keys %clkfire)
#		{
#			out("DSI: clock '$dl' flips in $clkfire{$dl}!\n");
#		}

		# Advance time until next 0->1 transition on our clock
		# and then on the indicated number of cycles
		if($sigint{$clkbase} eq '1')
		{
			for($i=0;$i<$cy;$i++)
			{
				
				$benchstim.="		\#".($clks{$clkbase}/$mult/2).";\n";
				$benchstim.="		$clkbase=1'b1;\n";
				$benchstim.="		\#".($clks{$clkbase}/$mult/2).";\n";
				$benchstim.="		$clkbase=1'b0;\n";
			}
			# XXX clock flipping!!
			$t+=$clkfire{$clkbase}+($cy-1)*$clks{$clkbase};
		}
		else
		{
			for($i=0;$i<$cy;$i++)
			{
				
				$benchstim.="		\#".($clks{$clkbase}/$mult/2).";\n";
				$benchstim.="		$clkbase=1'b0;\n";
				$benchstim.="		\#".($clks{$clkbase}/$mult/2).";\n";
				$benchstim.="		$clkbase=1'b1;\n";
			}
			# XXX clock flipping!!
			$t+=$clkfire{$clkbase}+($cy-0.5)*$clks{$clkbase};
		}
		# Avoid rounding errors
		$t=int($t/$mult+0.5)*$mult;
		$clkfire{$clkbase}=$clks{$clkbase}/2;

		# XXX must handle correctly advancing other clocks
		# (in case the user then switches clkbase)
		undef %assignedto;
	}
	else
	{
	if($a eq "!")
	{
		if($clkbase eq '')
		{
			bail("","ERROR: need to set clock reference with \"\@\" command "
		."before using \"!\" command on line $lno.\n");
		}

		if($cmd=~/\A\!([^\:]+)\z/)
		{
			$d=$1;
			# check sig

			out("DSI: got a money train '$d', single clock.\n");
		}
		else
		{
			if($cmd=~/\A\!([^\:]+)\:(\d+)\z/)
			{
				$d=$1;
				$e=$2+0;
				if($e==0)
				{
					bail("","ERROR: minimum number of clocks "
		."to advance in pulse command is 1 on line $lno.\n");
				}
			
				# check sig


				out("DSI: got a money train '$d' '$e'.\n");

			}
			else
			{
				bail("","ERROR: illegal pulse command ('$cmd') "
		."on line $lno. Use '!mysig' for one clock pulse and '!mysig:3' "
		."for three, for example.\n");
			}
		}

		undef %assignedto;

	}
	else
	{
	if($cmd=~/\A([^\=]+)\=(.+)\z/)
	{
		#out("DSI: got an '=' in '$cmd'.\n");
		$d=$1;
		$e=$2;
		unless(exists($sigs{$d}))
		{
			bail("","ERROR: unrecognised signal name '$d' in value "
				."assignment on line $lno.\n");
		}
		if(exists($clks{$d}))
		{
			bail("","ERROR: unable to use assignment commands "
				."on clocks, including '$d' on line $lno.\n");
		}
		if(exists($assignedto{$d}))
		{
			bail("","ERROR: assignment to same signal ('$d') attempted "
			."without the advance of time, lines $assignedto{$d} "
			."and $lno.\n");
		}
		
		$sigint{$d}=parseval($e,$sigs{$d},$d,"assignment command");

		out("DSI: assigned value ".(($sigs{$d}>1)?"\%":"")."$sigint{$d} "
			."for signal '$d'.\n");

		$assignedto{$d}=$lno;

	}
	else
	{

		#bail("","ERROR: unknown command '$cmd' on line $lno.\n");
		caution("WARNING: unknown command '$cmd' on line $lno.\n");
	}}}}
	updatestate();
}

###### Command main loop

$t=0;
$clkbase="";
undef %assignedto;
if($stimno==0) {bail("","ERROR: missing .begin directive before stimulus.\n");}
$lno=$stimno;
splice(@file,0,$stimno-1);
$prevdump="";
foreach $l (@file)
{

	chomp($l);
	$a=substr($l,0,1);
	if(($a eq '#')||($a eq '*'))
	{
		# comment or end of scan, so ignored line
	}
	else
	{
		#out("DSI: '$l'\n");
		@cmds=split(/\s+/,$l);
		foreach $c (@cmds)
		{
			$tp=$t;
			stim($c);
			if($tp!=$t) {out("DSI: t=${t}s (".($t*($m/$mult))."$mtxt).\n");}
			$f=dumpstate;
			if($f ne $prevdump)
			{
				#out($f); 
				$prevdump=$f;
			}
		}
	}
	$lno++;
}




############# EXPORT VERILOG TESTBENCH


bench("// Verilog testbench file generated from $ARGV[0] by DSI release $ver *\n");
bench("// URL: $url *\n");
bench("//\n\n");

bench("// set timescale from multiplier\n\`timescale $m$mtxt / $m$mtxt\n\n");

bench("module testbench();\n\n");

@modin=(sort(keys %sigs));
bench("	// stimulus inputs to module\n");
foreach (@modin)
{
	$wid=$sigs{$_}-1;
	if($wid)
		{bench("	reg [$wid:0] $_;\n");}
	else
		{bench("	reg $_;\n");}
}

@modout=(sort(keys %benchsigs));
if(@modout)
{
	bench("\n	// outputs from module\n");
}
foreach (@modout)
{
	$wid=$benchsigs{$_}-1;
	if($wid)
		{bench("	wire [$wid:0] $_;\n");}
	else
		{bench("	wire $_;\n");}
}

bench("\n	// instantiate module\n	$g test_$g(");

for($i=0;$i<=(scalar(@modin)-1);$i++)
{
	bench(".$modin[$i]($modin[$i])");
	if($i<(scalar(@modin)-1)) {bench(",");}
}

if(@modout)
{
	for($i=0;$i<=(scalar(@modout)-1);$i++)
	{
		bench(",.$modout[$i]($modout[$i])");
	}
	#bench(join(",",@modin).",".join(",",@modout));
}
bench(");\n\n");

bench("	initial\n	begin");

if(@benchinit)
{
	bench("\n		// user-specified initial commands\n");
	foreach (@benchinit)
	{
		bench("		$_\n");
	}
}

if(@benchmonitor)
{
	bench("\n		// user-specified monitor parameters\n");
	bench("		\$monitor(\n");
	foreach (@benchmonitor)
	{
		bench("			$_\n");
	}
	bench("		);\n");
}

bench("\n		// set up initial values\n");

foreach (keys %sigs)
{
	bench("		$_=$sigs{$_}'b$sigint{$_};\n");
}

bench("\n		// stimulus section\n");

# patch up stimulus in testbench (pre0.6)
# any clock assignments must follow other assignments
# this is really too messy but works fine
foreach $z (keys %clks)
{
	$b2="";
	while($b2 ne $benchstim)
	{
		$b2=$benchstim;
		$benchstim=~s/(\t\t\#\d+.+\n)\t\t($z\=1\'b1;\n)([^#]+)/$1$3$2\t\t/g;
	}	
}

bench($benchstim);

bench("\n\n		\$display(\"DSI: End of stimulus reached.\");\n");


if($benchend eq 'quit')
{
	bench("\n		// exit simulation\n");
	bench("		\$finish(2);\n");
}
else
{
	if($benchend eq 'stop')
	{
		bench("\n		// remain in simulation environment\n");
		bench("		\$stop;\n");
	}
	else
	{
		bench("\n		// continue simulation, requiring manual intervention to end\n");
	}
}

bench("\n	end\n\n");


bench("endmodule\n\n\n");


############# EXPORT SPICE FILE

# All the hard work has already been done in updatestate()
# We just need to dump the strings

spice("* Spice stimulus generated from $ARGV[0] by DSI release $ver *\n");
spice("* URL: $url *\n");
spice("*\n");
spice(".subckt invl1 vddconn vssconn in out
Mpmosinv1 out in vddconn vddconn P L=DSILMIN W=\"DSIWMIN*4\"
Mnmosinv1 out in vssconn vssconn N L=DSILMIN W=\"DSIWMIN*2\"
.ends invl1
");
spice("**********\n");

spice("* Clocks *\n");
spice("**********\n");

# HSpice format
# pulse(base_voltage pulsed_voltage delay_before_pulse rise_time fall_time pulse_width period)

foreach $z (sort(keys %clks))
{
		spice("V$z $z 0 pulse($sigvss{$z} $sigvdd{$z} $clkdelay{$z} $clkrise{$z} $clkfall{$z} ".
#			((($clkdelay{$z}==0)?("$clkh{$z}"):("$clkl{$z}"))+2*$clkrise{$z}).
			((($clkdelay{$z}==0)?("$clkh{$z}"):("$clkl{$z}"))).
			" $clks{$z})\n");
}
spice("*\n");
spice("* Signals *\n");
spice("***********\n");

foreach $z (sort(keys %spice))
{
		$znobr=$z;
		$znobr=~s/(\[|\])//g;
		while(substr($spice{$z},-1) eq ' ')
		{
			$spice{$z}=substr($spice{$z},0,-1);
		}
		spice("V$z _dsi_ideal_${z} 0 pwl($spice{$z})\n");
		spice("Vposs_$z _dsi_poss_$z 0 DC +$sigvdd{$znobr}V\n");
		spice("Vnegs_$z _dsi_negs_$z 0 DC +$sigvss{$znobr}V\n");
		spice("Xinvl1_$z _dsi_poss_$z _dsi_negs_$z _dsi_ideal_${z} _dsi_one_${z} invl1\n");
		spice("Xinvl2_$z _dsi_poss_$z _dsi_negs_$z _dsi_one_${z} _dsi_two_${z} invl1\n");
		spice("Xinvl3_$z _dsi_poss_$z _dsi_negs_$z _dsi_two_${z} ${z} invl1\n");
		#spice("Xinvl1_$z _dsi_poss_$z _dsi_negs_$z _dsi_ideal_${z} ${z} invl1\n");
}

$end=time()-$starttime;
$end++ if($end==0);
out("DSI: Finished processing (<$end second".plu($end).").\n");


exit(0);


# End of dsi.pl

