######################################################################################
#
# scanlog_waivers.pm - This file classifies warnings/errors for a generic logfile
#    The main functions that should be customized to the project are
#
#    check_for_error -  Initial criteria to use to see if current logfile line is GOOD/WARNING/ERROR
#    check_known     -  Checks if a warning/error is something we know about and need to fix in the future.  Like using an evaluation version of some IP or a known BUG 
#    check_waived    -  Checks if a warning/error is something we don't care about and can't fix.  Like a warning coming from "golden" IP.
#
#  To add a waiver you are using some regular expression match with the current line in the log file ($currLine) EX:
#       if(($status eq "ERROR") && ($currLine =~ /\+MAXERRS=/)) {$comment = "MJS - 11/17/17 - We use MAXERRS on cmdline to specify how many errors to log, but this isn't an err."};
#
#  We can also use a buffer containing some # of lines before and after the line ($lineBuf where $errLineNum is the current line) 
#       EX:  If synthesis sees a LBR-38 warning we can ignore it if the cell (which is reported on the following line)  is cdn_hs_phy_adrctl_slice.
#       if(($currLine =~ /LBR-38/) && ($lineBuf[$errLineNum+1] =~ /cdn_hs_phy_adrctl_slice/)) {
#           $comment = "MJS - 12/12/17 Somehow the 2 libraries cdn_hs_phy_adrctl_slice + other have different operating conditions"; }
#
#  Additionally we can use $status="ERROR"/"WARNING" or the $filename where the error occurs.
#
#
#  When setting a warning to either KNOWN or WAIVED a useful comment should be set that contains 
#     1) Who is making the change
#     2) When the change was made
#     3) Why we are ignoring this and any appropriate bugtracks bug#
#
package scanlog_waivers;

use strict;
use warnings;
use diagnostics;
use Exporter 'import';
our $VERSION = '1.00';
our @EXPORT = qw(check_waivers export_waiver_vars); # $prefixLines $postfixLines $lineBufLen);


my $prefixLines;  
my $postfixLines; 
my $lineBufLen;   
my $scanlog_debug;
my $warnings_as_errors;



my $fileName;
my @lineBuf;
my $errLineNum;
my $fileLineNum;
my $lineStatus;
my $currLine;
my $comment;
my $errstat;



##############################################################################################33
#  WAIVER Configurations
##############################################################################################33
BEGIN{

    #Setup how many lines of buffer to save before/after the current line, This is needed if you have errors that span multiple lines.
    $prefixLines        = 10;   #Number of lines before the current line to save.
    $postfixLines       = 10;   #Number of lines after the current line to save.
    $lineBufLen         =  $prefixLines + $postfixLines + 1;  #Total buffer linBufLen is pre+post+current line.

    $warnings_as_errors = 0;  #Treats all WARNINGS as ERRORS

    $scanlog_debug      = 0; #Displays the line buffer when a WARNING/ERROR detected so you can debug your waiver.
}



##############################################################################################33
#
# check_for_error()  - This subroutine determines what is or is not an error/warning on the current input line.  It is CRITICAL that this is done right so we don't miss anything
#   If some error doesn't fit this signature it would be BAD.
#
#
##############################################################################################33
sub check_for_error {
    $errstat = "GOOD";

    if($currLine =~ /FAIL|UVM_ERROR|UVM_FATAL|Error|\sERR|\sASSERT|\sCycle limit reached|\*E,|\*F,|\sViolation|No rule to make target/){ #Error Detected
	$errstat =  "ERROR";
    }
    
    if($currLine =~ /WARN|\*W,|UVM_WARNING|Warning/){
	$errstat =  "WARNING";	
    }

    if($warnings_as_errors && ($errstat eq "WARNING")) {
	$errstat = "ERROR";
    }

    #Occasionally there are some matched items that we can throw away without a waiver.  Something like having a port named "FatalError".  These can be dealt with right 
    #Here to avoid anything showing up in our error statistics.

    #If Debug is enabled print the current buffer on each error/warning so we can debug the waivers.
    if($scanlog_debug & ($errstat ne "GOOD")){
	print_line_buf();
    }


    return $errstat;
}



##############################################################################################
#
# check_known()  - This subroutine Checks against a list of known issues.  The intent here is for Verification to 
#               Add to this when we detect an issue, but it has not been fixed yet.  At the end of the project there should be 0 items here.
#               With everything either being waived(in the next function) or resolved in the RTL/TB source.
#
#  Useful library variables for this function:
#   $fileName    - File Name that is being processed.  
#   $fileLineNum - Line # in the file that scanlogs is currently processing.
#   $lineStatus  - WARNING or ERROR  based on how scanlogs detects things. (ex *W vs *E)
#   $currLine    - Contents of the logfile line indicating an error/warning.
#
#   For Errors that span multiple lines of there is also: 
#   @lineBuf     - Small buffer of lines around the error.  (Usually 2 lines prior and 5 lines after the error)
#   $errLineNum  - Line # within this buffer which is indicating the error such that $currLine = @lineBuf[$errLineNum]
#
# Returns
#  $comment = Description of what we know about this line or "NONE"
#
##############################################################################################
sub check_known { 
  $comment = "NONE";

  #Here is where you would add exclusions for any KNOWN issues.  A known issue is something we know about, but have not decided to waive because we intend to fix in the future.
  # Please look at the examples at the top of this file on how to add an exclusion

  return $comment;
}

##############################################################################################
#
# check_waived()  - This subroutine Checks against a list of waived issues.  The intent here is for Design/Verification to waive issues that can not be fixed in the RTL/TB.
#
#
#  Useful library variables for this function:
#   $fileName    - File Name that is being processed.  
#   $fileLineNum - Line # in the file that scanlogs is currently processing.
#   $lineStatus  - WARNING or ERROR  based on how scanlogs detects things. (ex *W vs *E)
#   $currLine    - Contents of the logfile line indicating an error/warning.
#
#   For Errors that span multiple lines of there is also: 
#   @lineBuf     - Small buffer of lines around the error.  (Usually 2 lines prior and 5 lines after the error)
#   $errLineNum  - Line # within this buffer which is indicating the error such that $currLine = @lineBuf[$errLineNum]
#
# Returns
#  $comment = Description of what we know about this line or "NONE"
#
#
##############################################################################################
sub check_waived {
  
  $comment = "NONE";

  # Ignore use of warning/error strings in report summaries
  if(($currLine =~ /Errors/) && ($lineBuf[$errLineNum-2] =~ /Analysis summary :/)) {
      $comment = "01/23/20 APD: Ignore Errors count string in Analysis summary";
  }

  if(($currLine =~ /Warnings/) && 
     (($lineBuf[$errLineNum-5] =~ /Analysis summary :/) ||
     ($lineBuf[$errLineNum-2] =~ /Analysis summary :/))) {
      $comment = "01/23/20 APD: Ignore Warnings count string in Analysis summary";
  }
  return $comment;
}


##############################################################################################
#
# check_waivers()  - This subroutine Checks a detected warning/error against the Elaboration waiver lists
#   Input:
#   $fileName     = Filename being checked  (can be used to waive errors based on filename
#   $fileLineNum  = Raw Line number where this file occurs in the logfile.
#   $errLineNum   = Line # containing the error in the @lineBuf,  Default is 2.
#   \@lineBuf     = Buffer containing file lines bracketing the error. While normally we only care about the line that shows an error, some errors display on multiple lines.  
#                   scanlogs is set to capture several lines of input prior to the error as well as several lines after the error (default 2 before + 5 afterwards) This can be used when checking waivers.
#   
# Returns
#  $lineStatus = Enum of "GOOD" "WARNING" or "ERROR" 
#  $found      = Enum if warning either "NEW" "KNOWN" "WAIVED" or "OK"
#              "NEW"     - This error/warning was not recognized by this parser.
#              "KNOWN"   -  This error/warning is something we know about but haven't decided whether or not it should be waived.
#              "INVALID" -  This was never an error/warning in the first place and shouldn't be counted against the design.  For example setting some parameter like "+MAXIMUM_NUM_ERRORS=2" would likely be flagged by scanlogs but obviously isn't an error.
#  $comment = Description of why this error is known/waived or "NONE"#  
#
##############################################################################################

sub check_waivers {
    #Copy variables out of input array.
    $fileName    = $_[0];
    $fileLineNum = $_[1];
    $errLineNum  = $_[2];
    my $arr_ref  = $_[3];

    @lineBuf = @$arr_ref;

    $currLine = $lineBuf[$errLineNum];    

    my $found = "NEW";
    my $msg;
    
    $comment = "NONE";

    #Check to see if current line matches error/warning criteria
    $lineStatus = check_for_error();


    if($lineStatus ne "GOOD") {
        #Check to see if problem is something we know about.
	$comment = check_known();
	if($comment ne "NONE") {
	    #This is a known (but not waived) issue.
	    $found = "KNOWN";
	} else {
	    #Check to see if this issue was waived.
	    $comment = check_waived();
	    if($comment ne "NONE") {
		#This is an issue that has been waived.
		$found = "WAIVED";
	    }
	} 


    }
    
#    $msg = sprintf("check_waivers returning %s %s %s \n", $lineStatus,  $found, $comment);
#    print $msg;
    
    return ($lineStatus, $found, $comment);    
}

sub export_waiver_vars {
    return ($prefixLines, $postfixLines);
}


sub print_line_buf {
    my $errMsg;
    print "------------------------------------------", $fileLineNum, "-------------------------------------------------\n";
    for(my $iter=0;$iter<$lineBufLen;$iter++){
	$errMsg = sprintf("%5d:  %s\n",$iter - $prefixLines, $lineBuf[$iter]);
	print $errMsg;
    }
    print "-----------------------------------------", $fileLineNum, "-------------------------------------------------\n\n\n";
}




1;
