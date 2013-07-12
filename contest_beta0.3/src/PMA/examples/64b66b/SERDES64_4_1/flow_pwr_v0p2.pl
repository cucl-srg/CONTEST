#!/usr/bin/perl -w

# Written by Yury Audzevich
#
# Comments, suggestions for improvement and criticism welcome
# E-mail:  yury.audzevich~at~cl.cam.ac.uk
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

### Revisions 
# --------------------------------------------------
# v_01 -- flow_pwr_v0p1.pl 
# The first public release of the script.
# Total power is concat of power meas. from individual
# cells which resulted in extremely long strings for 
# complex MCML cell netlists. May result in an error
# (string is too long) during HSPICE measurements.

# --------------------------------------------------
# v_02  -- flow_pwr_v0p2.pl
# Previous issue has been fixed by splitting a final 
# power measurement into multiple instances.


###########################################################################
###########################################################################
########################## IMPORTANT ######################################
### This routine is written for a specific file structure used in 	###
### HSPICE simulation. It refers to a specific set of files and 	###
### extracts the necessary information about the current simulation	###
### setup. Please note that any modifications to the existing 		###	
### structure will require corresponding modifications to be		###
### made to this program.						###
###########################################################################
### The program generates a netlist of HSPICE measurement statements to ###	
### estimate the power taken by every component of the system. 		###
### Accounts cells composed both of CMOS && MCML logic levels.		###
### All the information is extracted based on the specified TAGs.	###
### Please check/modify TAGs according (main subprogram) to your needs.	###	
### Please specify the search directory to instantiate the script.	###
###########################################################################
###########################################################################
###########################################################################		

##### MAIN program loop is defined below ######

##### Define subroutines first ####

# match input pattern
sub match_pattern 
{
  my($sub_str, @list) = @_;

  my(@ret_list) = ();
  foreach (0..$#list)
  {
	  if ($list[$_] =~ /$sub_str/)
	  {
		  push(@ret_list, $list[$_]);
	  }     
  }  
  return @ret_list;  
}	

# exit with error
sub jmp_out {
	print STDERR $_[0] , "\n";
	exit(1);
}

# print list
sub print_list 
{
	my @plist = @_;
	foreach (0..$#plist)
	{
		print $plist[$_], "\n";
	}
	
	undef @plist;
}

# Extract required files based on the directory and tags
sub extract_files
{	
	my ($ref_dirs, $ref_tags) = @_;
	my $argd = scalar(@{$ref_dirs});
	
	if ($argd == 1) 
	{	
		#check folder exists
		my $dird =  shift(@{$ref_dirs}); 
		opendir(DH, $dird) || die("Cannot open $dird: $! \n");
		close(DH);
			
		#fetch all files from folder
		my @all_files = <$dird/*>; 
		
		#main params
		my @ret_list = ();
				
		#main search loop	
		foreach (0..$#{$ref_tags})
		{			
			#tag->file association	
			my @tfa = &match_pattern(${$ref_tags}[$_], @all_files);
			my $s_tfa = scalar(@tfa);
					
			#check files	
			if(($s_tfa > 0) && ($s_tfa < 2)) 
			{
				my $file_name = shift(@tfa); 
				
				#verify correctness
				if(-z $file_name)  {jmp_out("\n ERROR: zero-length input file.\n");}
				if(!-e $file_name) {jmp_out("\n ERROR: input file does not exist.\n");}
				
				#approve
				push(@ret_list, $file_name);	
				undef $file_name;					
			} 
			elsif ($s_tfa > 1)
			{
				jmp_out("\n ERROR: Please refine the search of file with tag <${$ref_tags}[$_]>.\n");	
					 				
			}
			else 
			{ 
				jmp_out("\n ERROR: File with tag <${$ref_tags}[$_]> was not found. \n");
				
			}			
			undef $s_tfa;
			undef @tfa;					
		}
		undef @all_files;	
				
		return @ret_list;
	} else 
	{
		die( "\n  Use: perl $0 dir/with/test/files \n\n" ); 
	}	
}

sub gen_cmos_sources
{
	#retain file ordering 
	my ($ref_files, $out_name) = @_;
		
	print "\n################################################\n";
	print "Searching for CMOS power supplies. \n";		
	print "Extracting info from <${$ref_files}[0]> and <${$ref_files}[1]> files. \n";
		
	if ( -e ${$ref_files}[0] ||  -e ${$ref_files}[1]) 
	{
		open($testf, '<', ${$ref_files}[0]) || die("ERROR: unable to open file <${$ref_files}[0]>\n");
		open($initf, '<', ${$ref_files}[1]) || die("ERROR: unable to open file <${$ref_files}[1]>\n");
	}
	       		
	## voltage source definitions -> test.spi
	# Example search: 'V'dd_ser_'cmos' VDD_PISO20_2 0 'CMOS'_'VDD'_LEVEL  
	my @vdd_supplies_test = ();	
	while (defined($_ = <$testf>))
	{			
		if ($_ =~ /$vsource_tag.*$cmos_tag.*$vdd_tag/i)
		{	   	
			push(@vdd_supplies_test, $_);		
		}			
	}
	
	## voltage source instantiations -> instantiation.spi
	## line has "vdd" and doesn't have "vdd_mcml"
	my @vdd_supplies_inst = ();	
	while (defined($_ = <$initf>))
	{	
		my @result = ();		
		if (($_ =~ /.*$vdd_tag.*/i) && ($_ !~ /.*$mcml_vdd_tag.*/i))
		{	
			@result = split(" ", $_);			
			foreach (0..$#result)
			{				
				if ($result[$_] =~ /.*$vdd_tag.*/i)
				{
					# avoid repetition
					my $val =  $result[$_];
					my $cntr = 0;
					foreach (0..$#vdd_supplies_inst)
					{
						if ($val eq $vdd_supplies_inst[$_]) {$cntr++;}						
					}
					if ($cntr == 0) {push(@vdd_supplies_inst,$val);	}
				}
			}			
		}
		undef @result;			
	}
	
	close($testf);
	close($initf);
	
	#all supply definitions 
	print "\n--- Power supply definitions found: --- \n";
	&print_list(@vdd_supplies_test);
	
	#actual instantiation names
	print "\n--- Power supply instantiations found: --- \n";
	&print_list(@vdd_supplies_inst);
		
	print "\nGenerating CMOS-level measurement netlist. \n";
	print "Saving netlist to: <$out_name> \n";
	
	open($outf, '>', $out_name) || die("ERROR: unable to open output file <$out_name>\n");				
	print $outf " *** ============================================================= *** \n";
	print $outf " *** POWER MEASUREMENTS -- CMOS SERDES ONLY *** \n";
	print $outf " *** ============================================================= *** \n";
	print $outf " *** CMOS LEVEL LOGIC *** \n";
	
	# output measurements
	while ($element = shift(@vdd_supplies_inst))
	{
		foreach (0..$#vdd_supplies_test)
		{			
			if ($vdd_supplies_test[$_] =~ /.*$element.*/i)
			{				
				my $front = shift(@{[split(" ", $vdd_supplies_test[$_])]});
				my $tail = pop(@{[split(" ", $vdd_supplies_test[$_])]});
							
				print $outf " .MEASURE TRAN Idd_$front AVG I($front) FROM=FROM_TS TO=TO_TS \n";
				print $outf " .MEASURE POWER_$front Param=\'abs(Idd_$front)*$tail\' \n";
				undef $front;
				undef $tail;				
			}			
		}
	}
	undef $element;
	
	# all instances of supplies has been processed	
	if (scalar(@vdd_supplies_inst) == 0)
	{
		print $outf " *** ============================================================= *** \n";
		print "Netlist has been sucessfully generated! \n";
		print "################################################\n";
	}

	close($outf);	
	undef @vdd_supplies_inst;
	undef @vdd_supplies_test;	
}# gen_cmos_sources

sub gen_mcml_sources
{
	#retain file ordering
	my ($ref_files, $out_name) = @_;
		
	print "\n################################################";
	print "\nSearching for CMOS-level power supplies used in MCML cells. \n";
	print "Extracting info from <${$ref_files}[0]>, <${$ref_files}[1]>, <${$ref_files}[2]>, <${$ref_files}[3]> files. \n";
	
	
	###################################################################################
	### STEP1: -- CMOS level power supplies as part of MCML circuit first --- ###
	###################################################################################	
	if ( -e ${$ref_files}[0] ||  -e ${$ref_files}[1]) 
	{
		open($testf, '<', ${$ref_files}[0]) || die("ERROR: unable to open file <${$ref_files}[0]>\n");
		open($initf, '<', ${$ref_files}[1]) || die("ERROR: unable to open file <${$ref_files}[1]>\n");
	}
	       		
	##supply definitions from test.spi --> vdd_supplies_test()	
	my @vdd_supplies_test = ();	
	while (defined($_ = <$testf>))
	{	
		if ($_ =~ /$vsource_tag.*$cmos_tag.*$vdd_tag/i)
		{	   	
			push(@vdd_supplies_test, $_);		
		}			
	}
	
	##supply instantiations form instantiations.spi -> vdd_supplies_inst()
	my @vdd_supplies_inst = ();	
	while (defined($_ = <$initf>))
	{	
		# mcml circuit usually has "vdd_mcml" and "vdd_cmos" tags 
		if (($_ =~ /.*$mcml_vdd_tag.*/i) && ($_ =~ /.*$cmos_vdd_tag.*/i))
		{	
			my @result = split(" ", $_);
			
			# one supply can be used by many cells - avoid repetition			
			foreach (0..$#result)
			{
				if ($result[$_] =~ /.*$cmos_tag.*/i)
				{
					my $val =  $result[$_];
					my $cntr = 0;
					foreach (0..$#vdd_supplies_inst)
					{
						if ($val eq $vdd_supplies_inst[$_]) {$cntr++;}						
					}
					if ($cntr == 0) {push(@vdd_supplies_inst,$val);	}
				}

			}
			undef @result;						
		}		
	}
		
	close($testf);
	close($initf);	
	
	# all CMOS supplies definitions
	print "\n--- Power supply definitions found: --- \n";
	&print_list(@vdd_supplies_test);
	# instantiations	
	print "--- Power supply instantiations found: --- \n";
	&print_list(@vdd_supplies_inst);
	
	####################################################################################	
	# match instances found with corresponding definitions;
	# generate measurement netlist for each power supply used; 
	print "\nGenerating CMOS-level MCML-related measurement netlist.\n";
	print "Saving netlist to: <$out_name>\n";
	
	open($outf, '>', $out_name) || die("ERROR: unable to open output file <$out_name>\n");				
	print $outf " *** ============================================================= *** \n";
	print $outf " *** POWER MEASUREMENTS -- MCML SERDES ONLY *** \n";
	print $outf " *** ============================================================= *** \n";
	print $outf " *** CMOS LEVEL LOGIC *** \n";
	
	while (my $element = shift(@vdd_supplies_inst))
	{
		foreach (0..$#vdd_supplies_test)
		{			
			if ($vdd_supplies_test[$_] =~ /.*$element.*/i)
			{
				my $front = shift(@{[split(" ", $vdd_supplies_test[$_])]});
				my $tail = pop(@{[split(" ", $vdd_supplies_test[$_])]});
		
				print $outf " .MEASURE TRAN Idd_$front AVG I($front) FROM=FROM_TS TO=TO_TS \n";
				print $outf " .MEASURE POWER_$front Param=\'abs(Idd_$front)*$tail\' \n";
				undef $front;
				undef $tail;			
			}			
		}	
	}
	
	# every instance was processed		
	if (scalar(@vdd_supplies_inst) == 0)
	{
		print $outf " *** ============================================================= *** \n";
		print "Netlist has been sucessfully generated! \n";
		print "################################################\n";
	}

	# STEP1 -- DONE -- 
	close($outf);	
	undef @vdd_supplies_inst;
	undef @vdd_supplies_test;
	
	###################################################################################
	### STEP2: --- Measure currents at every individual MCML cell ---	####
	###################################################################################
	
	# netlist is tightly coupled to the individual MCML cells;
	print "\n################################################\n";
	print "Searching for MCML-level power supplies.\n";
	print "Extracting info from <${$ref_files}[0]>, <${$ref_files}[1]>, <${$ref_files}[2]>, <${$ref_files}[3]> files. \n";
		
	if ( -e ${$ref_files}[0]) 
	{
		open($testf, '<', ${$ref_files}[0]) || die("ERROR: unable to open file <${$ref_files}[0]>\n");		
	}
	
	##power supply definitions -->	@vdd_supplies_test
	@vdd_supplies_test = ();	
	while (defined($_ = <$testf>))
	{	
		if ($_ =~ /$vsource_tag.*$mcml_tag.*$vdd_tag/i)
		{	   	
			push(@vdd_supplies_test, $_);		
		}			
	}
	close($testf);
		
	print "\n--- Power supply definitions found: --- \n";
	&print_list(@vdd_supplies_test);
	
	# Extract all the MCML power supply instantiations used
	# together with a structure of a complex MCML cell.
		
	if (-e ${$ref_files}[1]) 
	{
		open($initf, '<', ${$ref_files}[1]) || die("ERROR: unable to open file <${$ref_files}[1]>\n");
	}
		
	# @temp --> remove "+" hspice-related circuit expansion symbols; every cell is now fits one line;
	my @temp = ();
	while (defined($_ = <$initf>))
	{		
		if (($_ =~ /^(\+).*/i)) 
		{
			my @temp_line  = split(" ", $_);
			shift(@temp_line);			
			$temp[$#temp] .= " ".join(" ", @temp_line);			
			undef @temp_line;
		}
		elsif(($_ !~ /^\s*\z/) && ($_ !~ /^(\*).*/i))
		{
			push(@temp, $_);
		}					
	}	
	close($initf);
	
	###### This cycle does three main functions:
	# 1) extracts MCML cell instances -> instantiation.spi,
	# 2) creates hierarchy of every complex MCML cell, making it flat, 
	# 3) extracts MCML power supplies, generates final netlist. 
	
	print "\n################################################\n";
	print "Decomposing complex MCML cells into a netlist with basic MCML cells. \n";  
	
	@vdd_supplies_inst = ();	
	while ($_ = shift(@temp))
	{	
		# extract mcml cells ONLY from instantiation.spi; dump everything else.			
		if (($_ =~ /([x-z]).*($mcml_tag).*($mcml_tag).*/i)) 
		{
			my $current_line = $_;
						
			print "\n*** ================================================================= ***";
			print "\nProcessing <", pop(@{[split(" ", $current_line)]}), "> MCML cell defined as <", shift(@{[split(" ", $current_line)]}),"> constructed of: \n";
			print "*** ================================================================= ***\n";
									
			# reference to the hierarchy of basic MCML cells composing the cell			
			my $mcml_netlist_ref = &gen_mcml_comp($current_line, ${$ref_files}[2], ${$ref_files}[3]);
					
			# extract MCML power supply instances and match to the corresponding definitions
			my @current_cell = split(" ", $current_line);
			foreach (0..$#current_cell)
			{				
				if ($current_cell[$_] =~ /.*$mcml_vdd_tag.*/i)
				{
					my $current_supply = $current_cell[$_];
					print "Using the following power supply instantiation <", $current_cell[$_], ">. \n";
						
					#use this instance to find supply definition in --> @vdd_supplies_test
					foreach (0..$#vdd_supplies_test)
					{
						if ($vdd_supplies_test[$_] =~ /.*$current_supply.*/i)
						{
							# record voltage level found
							my $tail_supply = pop(@{[split(" ", $vdd_supplies_test[$_])]});
							
							#generate measurements for every cell in hierarchy
							print "\nSaving netlist to: <$out_name> \n";
							print "Generating per-cell power measurement netlist. \n";
							open($outf, '>>', $out_name) || die("ERROR: unable to open output file <$out_name>\n");				
							print $outf " *** ============================================================= *** \n";
							print $outf " *** POWER MEASUREMENTS -- MCML SERDES ONLY *** \n";
							print $outf " *** ============================================================= *** \n";
							print $outf " *** MCML LEVEL LOGIC --> cell <", shift(@{[split(" ", $current_line)]}) , "> <", pop(@{[split(" ", $current_line)]}) , "> *** \n";
																	
							my @total_power = ();
							my $total_power_str = "";
							my $total_power_final = "";
							my $cntr = 0;
							foreach (0..$#{$mcml_netlist_ref})
							{
								#substitute . with _ specifically for current ID
								my $sub_str = ${$mcml_netlist_ref}[$_];
								$sub_str =~ s/\./\_/g;
								
														
								print $outf " .MEASURE TRAN Idd_", $sub_str," AVG I(",${$mcml_netlist_ref}[$_],") FROM=FROM_TS TO=TO_TS \n";
								print $outf " .MEASURE POWER_", $sub_str, " Param=\'abs(Idd_", $sub_str, ")*", $tail_supply, "\' \n";
								
								# total power 
								if ($_ == $#{$mcml_netlist_ref})
								{									
									$total_power_str .= " + "."POWER_".$sub_str." )\'";
									push(@total_power, $total_power_str);
									$total_power_str = "";
									
									#final power update
									$total_power_final .= " )\'";
																			
									print $outf " *** TOTAL POWER --> cell <", shift(@{[split(" ", $current_line)]}) , "> <", pop(@{[split(" ", $current_line)]}) , "> *** \n";
									
									# split total power instances
									foreach (0..$#total_power)
									{
										print $outf $total_power[$_], "\n";
									}
									
									# print 
									print $outf $total_power_final, "\n";
									print $outf " *** --- MEASUREMENT COMPLETE --- *** \n\n";											
									$total_power_final = "";
								}
								elsif($_ == 0)
								{	
									#split total power into chunks of 10 -- hspice has problems with long lines								
									$total_power_str = ".MEASURE POWER_".shift(@{[split(" ", $current_line)]})."\[$cntr\]"." Param=\'( "."POWER_".$sub_str;	
									
									
									#calc resulting power								
									$total_power_final = ".MEASURE POWER_".shift(@{[split(" ", $current_line)]})." Param=\'(". "POWER_".shift(@{[split(" ", $current_line)]})."\[$cntr\]";
									#print $total_power_final, "\n"; 
								}
								elsif(($_ != 0) && (($_ % 10) == 0))
								{
									++$cntr;									
									$total_power_str .= " )\'";
									push(@total_power, $total_power_str);
																			
									$total_power_str = "";									
									$total_power_str = ".MEASURE POWER_".shift(@{[split(" ", $current_line)]})."\[$cntr\]"." Param=\'( "."POWER_".$sub_str;	
									
									#total final power
									$total_power_final .= " + "."POWER_".shift(@{[split(" ", $current_line)]})."\[$cntr\]";								
								}								
								else 
								{
									$total_power_str .= " + "."POWER_".$sub_str;
								}
								
								undef $sub_str;					
							} 
														
							undef @total_power;
							undef $total_power_str;
							undef $total_power_final;
							undef $cntr;
						
							undef $tail_supply;
							close($outf);
							
							print "Netlist has been successfully generated! \n";
						} 			
					}						
					undef $current_supply;																	
				}				
			}				
			undef @current_cell;
			undef $current_line;	
		}				
					
		@{$mcml_netlist_ref} = ();
		undef @{$mcml_netlist_ref};		
	}			
			
	# STEP2 -- DONE -- 
	print "\n################################################\n";
	undef @temp;
			
}# gen_mcml_sources

# represent a complex MCML cell as a set of basic ones  
sub gen_mcml_comp
{
	my ($in_line, $comp_file, $base_file) = @_;
	if (scalar(@_) == 3)
	{		
		my $sfile;
		if ( -e $comp_file) 
		{
			open($sfile, '<', $comp_file) || die("ERROR: unable to open file <$comp_file>\n");		
		}
			
		# cell type
		my $search_line = pop(@{[split(" ", $in_line)]});
		# cell ID #
		my $head_word = shift(@{[split(" ", $in_line)]});
				
		
		# flat hierarcy --> @tail_words
		my @tail_words = ();
		my $indx = 0;
		while (defined($_ = <$sfile>))
		{	
			#indicate cell boundaries 
			if (($_ =~ /.*$subckt_tag.*/i) && ($_ =~ /.*\s$search_line\s/i)){$indx = 1;}
			elsif(($_ =~ /.*$ends_tag*/i) && ($_ =~ /.*\s$search_line\s/i)){  $indx = 0;}
			
			## cell detected
			if(($indx == 1)) 
			{
				## avoid spaces, comments, circuit def. extensions (+) and the first line (.subckt)
				if (($_ !~ /^\s*\z/) && ($_ !~ /^(\*).*/i) && ($_ !~ /^(\+).*/i) && ($_ !~ /.*$subckt_tag.*/i))
				{
					my $s_line = $_;
					my $ref_base = &gen_mcml_base($_, $base_file);
					my $s_ref_base = scalar(@{$ref_base}); 
					
					#base element found 
					if($s_ref_base > 0)
					{						
						foreach (0..$#{$ref_base})
						{	
							my $cstr = $head_word."\.".${$ref_base}[$_]; 
							push(@tail_words, $cstr);
							undef $cstr;
						}			
					}
					
					# base element was not found. Search element among the complex ones.
					# start search process all over again.
					elsif ($s_ref_base == 0)
					{	
						## open the second instance of composite.spi file						
						my $cfile;
						if ( -e $comp_file) 
						{
							open($cfile, '<', $comp_file) || die("ERROR: unable to open file <$comp_file>\n"); 
						}
												
						my $search_line_i = pop(@{[split(" ", $s_line)]});
						my $head_word_i = shift(@{[split(" ", $s_line)]});
												
						print "\nProcessing <$search_line_i> cell defined as <$head_word_i> constructed of: \n";
						
						#search the required cell, extract the netlist						
						my @tail_words_i = ();
						my $indx_i = 0;
						while (defined($_ = <$cfile>))
						{	
							if (($_ =~ /.*$subckt_tag.*/i) && ($_ =~ /.*\s$search_line_i\s/i)){$indx_i = 1;}
							elsif(($_ =~ /.*$ends_tag*/i) && ($_ =~ /.*\s$search_line_i\s/i)) {$indx_i = 0;}
			
							if(($indx_i == 1)) 
							{
								if (($_ !~ /^\s*\z/) && ($_ !~ /^(\*).*/i) && ($_ !~ /^(\+).*/i) && ($_ !~ /.*$subckt_tag.*/i))
								{
									my $ref_base_i = &gen_mcml_base($_, $base_file);
									my $s_ref_base_i = scalar(@{$ref_base_i}); 
														
									#base elements found update the main list
									foreach (0..$#{$ref_base_i})
									{	
										my $cstr_i = $head_word."\.".$head_word_i."\.".${$ref_base_i}[$_]; 
										push(@tail_words, $cstr_i);
										undef $cstr_i;
									}			
									
									@{$ref_base_i} = ();
									undef $ref_base_i;
									undef $s_ref_base_i;								
								}
							}
						}
																	
						close($cfile);
						undef $search_line_i;
						undef $head_word_i;
						undef @tail_words_i;
						undef $indx_i;
						# cell decomposed					
					} 					
					# element was not found - notify
					else 
					{
						print "Element <> was not found \n";
					}
					
					@{$ref_base} = ();
					undef $ref_base;
					undef $s_ref_base;			
				}
			}			 						
		}	

				undef $indx;
		close($sfile);	
		
		# push out the reference to hierarchy
		my $ref_tail_words = \@tail_words;
		return 	$ref_tail_words
	}
	else 
	{
		jmp_out("\n ERROR mcml_comp: Wrong number of input arguments. Use: <in_line><out_line><file_where_to_search> \n");
	}
}

# search current source transistor(s) in a basic MCML cell 
sub gen_mcml_base
{
	my ($in_line, $in_file) = @_;
	if (scalar(@_) == 2)
	{		
		my $sfile;
		if ( -e $in_file) 
		{
			open($sfile, '<', $in_file) || die("ERROR: unable to open file <$in_file>\n");		
		}
		my $search_line = pop(@{[split(" ", $in_line)]});
		my $head_word = shift(@{[split(" ", $in_line)]});
		
		# find a current source transistor(s) inside a basic cell				
		my @tail_words = ();
		my $indx = 0;		
		while (defined($_ = <$sfile>))
		{	
			if (($_ =~ /.*$subckt_tag.*/i) && ($_ =~ /.*\s$search_line\s/i)){ $indx = 1;}
			elsif(($_ =~ /.*$ends_tag*/i) && ($_ =~ /.*\s$search_line\s/i)) { $indx = 0;}
			
			# Example: M9 cc vrfn gnda gnda NMOS_VTL W=DLL_NSOURCE_WIDTH L=DLL_NSOURCE_LENGTH			
			if (($indx == 1) && ($_ =~ /.*$csource_tag.*/i))
			{					
				push(@tail_words, shift(@{[split(" ", $_)]}));				
				print "Processing <$search_line> cell defined as <$head_word>\n";								
			}			 						
		}	
	
		undef $search_line;
		undef $indx;
		close($sfile);
			
		foreach (0..$#tail_words)
		{
			$tail_words[$_] = $head_word."\.".$tail_words[$_];
		}
		
		# push out reference
		my $out_line = \@tail_words;
		
		undef $head_word;
		return 	$out_line;		
	} 
	else 
	{
		jmp_out("\n ERROR: Wrong number of input arguments. Use: <in_line><file_where_to_search> \n");
	}	
}#gen_mcml_base


#########################
### main program loop ###
#########################
{	
	##### Define file name-associated tags  
	##### These are used for:
	##### 1) serching of power supply definitions and instantiations;
	##### 2) searching of definitions and instantiations of all MCML 
	#####    cells -- both complex and basic ones. 
	
	
	# the file with this TAG contains voltage source definitions
	$tag_f1 = "test.sp";
	
	# the file with this TAG contains all instantiations used in current
	# simulation; these include MCML cells, CMOS cells, other components. 
	$tag_f2 = "instantiation.sp";
	
	# file contains definitions of complex MCML cells composed of both 
	# complex and basic MCML cells.
	# Note: complex MCML cells should be decomposed to 
	# basic MCML cells in this file at some point.
	#  
	# Example: complex MCML_SERIAL[] cell uses complex MCML_DFF_MS cells, 
	# but these are decomposed to basic cells in the same file.
	$tag_f3 = "composite_cells.sp";
	
	# TAG for a file containing MCML basic cells ONLY
	$tag_f4 = "basic_cells.sp";

	###########################################
	#### OTHER TAGS used for identification of voltage sources, CMOS and
	#### MCML cells --> directly related to the names you give to the power
	#### sources, and MCML cells in <test> and <instantiation> files.
		
	#### MCML tag used in search of mcml cells
	$mcml_tag = "mcml";
	
	#### Voltage source definitions in HSPICE always start with "V"
	$vsource_tag = "v";
	
	#### CMOS logic related tag
	$cmos_tag = "cmos";
	
	#### default vdd tag
	$vdd_tag = "vdd";
	
	#### current source transistor tag
	$csource_tag = "source";
	
	#### standard hspice subcircuit beginning  
	$subckt_tag = "subckt";
	
	#### standard hspice subcircuit ending
	$ends_tag = "ends";
	
	#### default MCML vdd tag
	$mcml_vdd_tag = $vdd_tag."\_".$mcml_tag;
	
	#### default CMOS vdd tag
	$cmos_vdd_tag = $vdd_tag."\_".$cmos_tag;	
	
		
	############################################
	############# MAIN PROGRAM #################
	# dir with files under analysis
	$dir = shift(@ARGV);
		
	@a  = ($dir);
	@b  = ($tag_f1, $tag_f2, $tag_f3, $tag_f4);

	#extract all tagged files from the specified folder
	@c = ($file_test, $file_inst, $file_comp, $file_base) = &extract_files(\@a, \@b); 
	
	print "Current folder contains the requested files: \n";
	
	&print_list(@c);
	#print "$file_test \n";
	#print "$file_test \n";
	#print "$file_inst \n";
	#print "$file_comp \n";
	#print "$file_base \n";
	
	# generate measurement netlist for CMOS SERDES 
	&gen_cmos_sources([$file_test, $file_inst],"$dir/power_cmos_voltage.spi");

	# generate measurement netlist for MCML SERDES
	&gen_mcml_sources([$file_test, $file_inst, $file_comp, $file_base],"$dir/power_mcml_voltage.spi");

	#### DONE! ####
	
		

	
} ### end main

