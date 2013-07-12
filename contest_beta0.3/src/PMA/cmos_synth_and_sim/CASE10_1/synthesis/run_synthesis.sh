#!/bin/bash

# #
# # Written by Andrew West, Mar 2007
# #
# # Comments, suggestions for improvement and criticism welcome
# # E-mail:  Andrew.West~at~cl.cam.ac.uk
# #
# #
# # Copyright 2003-2013, University of Cambridge, Computer Laboratory. 
# # Copyright and related rights are licensed under the Hardware License, 
# # Version 2.0 (the "License"); you may not use this file except in 
# # compliance with the License. You may obtain a copy of the License at
# # http://www.cl.cam.ac.uk/research/srg/netos/greenict/projects/contest/. 
# # Unless required by applicable law or agreed to in writing, software, 
# # hardware and materials distributed under this License is distributed 
# # on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# # either express or implied. See the License for the specific language
# # governing permissions and limitations under the License.
# #
# #

# DC synthesis invokation script	
#
#
#  ./run_synthesis.sh NameOfYourToplevelModule [batch]
#
#   if 'batch' specified, quits after compile

############################################################################################
### Local setup script ###
pushd /usr/groups/ecad/synopsys
source setup.bash
popd
############################################################################################




### Build list of source Verilog files, excluding vendor simulation models ###

export ARG_SOURCES=`/bin/ls -1 Sources/*.v | grep -v DW_ | xargs -i -n1 echo $PWD/{} | xargs echo`


### script name ###

export SCRIPT_NAME="$PWD/flow_synth.tcl"



### CD into directory for run ###

mkdir 2>/dev/null tempdir.synth
mkdir 2>/dev/null out.synth
rm -rf out.synth/*.ddc
rm -rf out.synth/*.pvl
rm -rf out.synth/*.syn
rm -rf out.synth/*.mr
cd tempdir.synth
ln -sf ../kit

TOOL_NAME="design_vision -topo"


export ARG_TOPLEVEL="$1"

export ARG_TIMING="true"

export ARG_BLOCKS=""

echo "Toplevel: $ARG_TOPLEVEL"

if [ "$ARG_TOPLEVEL" == "" ] ; then
echo "Please specify toplevel as argument"
exit
fi

export ARG_QUITAFTERCOMPILE=false

if [ "$2" == "batch" ] ; then
        export ARG_QUITAFTERCOMPILE=true
        echo "Batch run enabled"
else
	if [ "$2" == "BATCH" ] ; then
	        export ARG_QUITAFTERCOMPILE=true
	        echo "Batch run enabled"
	fi
fi

PERL_PARAM_PROG='
shift(@ARGV);
open(FILE,">cmdlineparams.v") || die("Cannot open cmdlineparams.v for writing\n");
foreach $line (@ARGV)
{
	if($line=~/([^="]+)=(.*)"/)
	{
		print FILE "`define $1 $2\n";
	}
	else
	{
		if($line=~/([^="]+)=(.*)/)
		{
			print FILE "`define $1 $2\n";
		}
	}
}
close(FILE);
'

perl -e "$PERL_PARAM_PROG" "$@"
cat cmdlineparams.v
$TOOL_NAME -f $SCRIPT_NAME -no_home_init -64bit -wait 1 | tee run.output

## end of file
