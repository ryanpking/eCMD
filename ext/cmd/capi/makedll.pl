#!/bin/sh 
#! -*- perl -*-

eval '
if [ "X$ECMDPERLBIN" = "X" ] ; then
 if [ "X$CTEPATH" = "X" ]; then echo "CTEPATH env var is not set."; exit 1; fi
 export ECMDPERLBIN=$CTEPATH/tools/perl/5.8.1/bin/perl;
 export CTEPERLPATH=$CTEPATH/tools/perl/5.8.1;
 export CTEPERLLIB=$CTEPERLPATH/lib/5.8.1:$CTEPERLLIB;
fi

exec $ECMDPERLBIN -x -S $0 ${1+"$@"}
'
if 0;

# File makedll.pl created by Joshua Wills at 12:45:07 on Fri Sep 19 2003. 
# $Header$

use strict;

my $curdir = ".";

#constants
my $INT = 0;
my $VOID = 1;
my $STRING = 2;

#functions to ignore in parsing ecmdClientCapi.H because they don't get implemented in the dll, client only functions in ecmdClientCapi.C
my @ignores = qw( ecmdLoadDll ecmdUnloadDll ecmdCommandArgs ecmdSetup ecmdDisplayDllInfo InitExtension cmdRunCommand ecmdFunctionTimer);
my $ignore_re = join '|', @ignores;

# These are functions that should not be auto-gened into ecmdClientCapiFunc.C hand created in ecmdClientCapi.C
# Removed no_gen because it is an empty list now.  If things need to be re-added, uncomment the below two lines
# and the 3rd $no_gen_re line further down in the script - JTA 10/17/06
#my @no_gen = qw( );
#my $no_gen_re = join '|', @no_gen;

# These are functions that we want to check ring cache on.  If not added here, a function won't have ring cache checks
my @check_ring_cache = qw(getRing putRing getScom putScom sendCmd CfamRegister getArray putArray getTraceArray putTraceArray startClocks stopClocks iSteps SystemPower FruPower Spr Fpr Gpr Slb GpRegister);
my $check_ring_cache_re = join '|', @check_ring_cache;
# These functions have variable depth and require state fields, so we can use their state fields to do ring cache check
# Functions still need to be included above in check_ring_cache to work here
my $check_ring_cache_state_valid = "startClocks|stopClocks";
 
my $printout;
my $DllFnTable;
my @enumtable;
my $dllCapiOut;

# If no file is given, set the all flag
my $genAll = 0;
my $didFile = 0;
if ($ARGV[1] eq "") {
  $genAll = 1;
}

open IN, "${curdir}/$ARGV[0]ClientCapi.H" or die "Could not find $ARGV[0]ClientCapi.H: $!\n";
#parse file spec'd by $ARGV[0]
while (<IN>) {

    # Maintain the remove_sim and other ifdef's
    if (/REMOVE_SIM/ || 
        /_REMOVE_/ ) {

      $dllCapiOut .= $_;
      $printout .= $_;

    } elsif (/^(uint32_t|uint64_t|std::string|void|bool|int)/) {

	next if (/$ignore_re/o);

	my $type_flag = $INT;
	$type_flag = $VOID if (/^void/);
	$type_flag = $STRING if (/^std::string/);
        my $chipTarget = 0;
        $chipTarget = 1 if (/ecmdChipTarget/);

	chomp; chop;  
	my ($func, $args) = split /\(|\)/ , $_;

	my ($type, $funcname) = split /\s+/, $func;
	my @argnames = split /,/ , $args;

        #remove the default initializations
        foreach my $i (0..$#argnames) {
            if ($argnames[$i] =~ /=/) {
              $argnames[$i] =~ s/\s*=.*//;
            }
        }
        $" = ",";


        my $enumname;
        my $orgfuncname = $funcname;

        # WE never want to include a main function if it is in there
        next if ($funcname eq "main");

        if ($funcname =~ /ecmd/) {

           $funcname =~ s/ecmd//;

           $enumname = "ECMD_".uc($funcname);

           $funcname = "dll".$funcname;
        }
        else {

           $enumname = "ECMD_".uc($funcname);
           $funcname = "dll".ucfirst($funcname);
        }

	push @enumtable, $enumname;

        $dllCapiOut .= "$type $funcname(@argnames); \n\n";

        # Pulled because we no longer have functions that aren't auto generated - JTA 10/17/06
	#next if (/$no_gen_re/o);

        $printout .= "$type $orgfuncname(@argnames) {\n\n";

	
	$printout .= "  $type rc;\n\n" unless ($type_flag == $VOID);

	$printout .= "#ifndef ECMD_STATIC_FUNCTIONS\n\n";
	$printout .= "  if (dlHandle == NULL) {\n";
        $printout .= "    fprintf(stderr,\"$funcname\%s\",ECMD_DLL_NOT_LOADED_ERROR);\n";
        $printout .= "    exit(ECMD_DLL_INVALID);\n";
	$printout .= "  }\n\n";


	$printout .= "#endif\n\n";

        if ($ARGV[0] ne "ecmd") {
          $printout .= "  if (!".$ARGV[0]."Initialized) {\n";
          $printout .= "    fprintf(stderr,\"$funcname: eCMD Extension not initialized before function called\\n\");\n";
          $printout .= "    fprintf(stderr,\"$funcname: OR eCMD $ARGV[0] Extension not supported by plugin\\n\");\n";
          $printout .= "    exit(ECMD_DLL_INVALID);\n";
          $printout .= "  }\n\n";
        }

        #Put the debug stuff here
	if (!($orgfuncname =~ /ecmdOutput/)) {
	    $printout .= "#ifndef ECMD_STRIP_DEBUG\n";

	    # new debug10 parm tracing stuff
	    if(!($orgfuncname =~ /ecmdFunctionParmPrinter/)) {
		#if($#argnames >=-1) {
		if(1) {
		    $printout .= "  int myTcount;\n";
		    $printout .= "  std::vector< void * > args;\n";
		    $printout .= "  if (ecmdClientDebug != 0) {\n";


#		    $printout .= "     ecmdFunctionParmPrinter(ECMD_FPP_FUNCTIONIN,\"$type $orgfuncname(@argnames)\"";

		    #
#		    my $pp_argstring;
#		    my $pp_typestring;
		    foreach my $curarg (@argnames) {

			my @pp_argsplit = split /\s+/, $curarg;

			my @pp_typeargs = @pp_argsplit[0..$#pp_argsplit-1];
			my $tmptypestring = "@pp_typeargs";

			my $tmparg = $pp_argsplit[-1];
			if ($tmparg =~ /\[\]$/) {
			    chop $tmparg; chop $tmparg;
			    $tmptypestring .= "[]";
			}

#			$pp_typestring .= $tmptypestring . ", ";
#			$pp_argstring .= $tmparg . ", ";
			$printout .= "     args.push_back((void*) &" . $tmparg . ");\n";
		    }

#		    chop ($pp_typestring, $pp_argstring);
#		    chop ($pp_typestring, $pp_argstring);
#		    $printout .= "," . $pp_argstring . ");\n\n";
		    $printout .= "     fppCallCount++;\n";
		    $printout .= "     myTcount = fppCallCount;\n";
		    $printout .= "     ecmdFunctionParmPrinter(myTcount,ECMD_FPP_FUNCTIONIN,\"$type $orgfuncname(@argnames)\",args);\n";
		    $printout .= "     ecmdFunctionTimer(myTcount,ECMD_TMR_FUNCTIONIN,\"$orgfuncname\");\n";
		    $printout .= "  }\n";
		} # end if there are no args
	    } # end if its not ecmdFunctionParmPrinter 
	    $printout .= "#endif\n\n";
	}

        if (/$check_ring_cache_re/) {


          $printout .= "   ecmdChipTarget cacheTarget;\n";
          if (/$check_ring_cache_state_valid/) {
            # State fields should be valid to appropriate depth, so just pass through
            $printout .= "   cacheTarget = i_target;\n";
          } elsif ($chipTarget) {
            $printout .= "   cacheTarget = i_target;\n";
            $printout .= "   ecmdSetTargetDepth(cacheTarget, ECMD_DEPTH_CHIP);\n";
          } else {
            # Temporary fix for I/P GFW so that the looper isn't called when the HOM isn't up
            # We don't do anything and just pass the cacheTarget right in
            # Also comment the while loop close up back in below
            ## Since this function doesn't take a cage, I need to loop over cages and check all caches
            #$printout .= "   ecmdLooperData looperdata;\n";
            #$printout .= "   cacheTarget.cageState = ECMD_TARGET_FIELD_WILDCARD;\n";
            #$printout .= "   rc = ecmdConfigLooperInit(cacheTarget, ECMD_ALL_TARGETS_LOOP, looperdata);\n";
            #$printout .= "   if (rc) return rc;\n\n";
            #$printout .= "   while (ecmdConfigLooperNext(cacheTarget, looperdata)) {\n";
          }

          if ($type_flag == $STRING) {
            $printout .= "   if (ecmdIsRingCacheEnabled(cacheTarget)) return ecmdGetErrorMsg(ECMD_RING_CACHE_ENABLED);\n";
          }
          elsif ($type_flag == $INT) {
            $printout .= "   if (ecmdIsRingCacheEnabled(cacheTarget)) return ECMD_RING_CACHE_ENABLED;\n";
          }
          else { #type is VOID
            $printout .= "   if (ecmdIsRingCacheEnabled(cacheTarget)) return;\n";
          }
          # Close up my while loop above 
          #if (!$chipTarget) {
          #  $printout .= "   }\n";
          #}

        }
	
	$printout .= "#ifdef ECMD_STATIC_FUNCTIONS\n\n";

	$printout .= "  rc = " unless ($type_flag == $VOID);

	$" = " ";
       
	if ($type_flag == $VOID) {
	    $printout .= "  ";
	}

	$printout .= $funcname . "(";

	my $argstring;
	my $typestring;
	foreach my $curarg (@argnames) {

	    my @argsplit = split /\s+/, $curarg;

	    my @typeargs = @argsplit[0..$#argsplit-1];
	    my $tmptypestring = "@typeargs";

	    my $tmparg = $argsplit[-1];
	    if ($tmparg =~ /\[\]$/) {
		chop $tmparg; chop $tmparg;
		$tmptypestring .= "[]";
	    }

	    $typestring .= $tmptypestring . ", ";
	    $argstring .= $tmparg . ", ";
	}

	chop ($typestring, $argstring);
	chop ($typestring, $argstring);

	$printout .= $argstring . ");\n\n";
	    
	$printout .= "#else\n\n";
	
	


        if ($ARGV[0] ne "ecmd") {
          $DllFnTable = "$ARGV[0]DllFnTable";
        } else {
          $DllFnTable = "DllFnTable";
        }

	$printout .= "  if (".$DllFnTable."[$enumname] == NULL) {\n";
	$printout .= "     ".$DllFnTable."[$enumname] = (void*)dlsym(dlHandle, \"$funcname\");\n";

	$printout .= "     if (".$DllFnTable."[$enumname] == NULL) {\n";

        $printout .= "       fprintf(stderr,\"$funcname\%s\",ECMD_UNABLE_TO_FIND_FUNCTION_ERROR); \n";
        # Defect 20342, display dll info in case of invalid symbol
        $printout .= "       ecmdDisplayDllInfo();\n";

        $printout .= "       exit(ECMD_DLL_INVALID);\n";

	$printout .= "     }\n";
	
	$printout .= "  }\n\n";

	$printout .= "  $type (*Function)($typestring) = \n";
	$printout .= "      ($type(*)($typestring))".$DllFnTable."[$enumname];\n\n";

	$printout .= "  rc = " unless ($type_flag == $VOID);
	$printout .= "   (*Function)($argstring);\n\n" ;
	
	$printout .= "#endif\n\n";


        #Put the debug stuff here
        if (!($orgfuncname =~ /ecmdOutput/)) {
	    $printout .= "#ifndef ECMD_STRIP_DEBUG\n";


	    # new debug10 parm tracing stuff
	    if(!($orgfuncname =~ /ecmdFunctionParmPrinter/)) {
		#if($#argnames >=0) {
		if (1) {
		    $printout .= "  if (ecmdClientDebug != 0) {\n";
		    $printout .= "     args.push_back((void*) &rc);\n" unless ($type_flag == $VOID);
		    $printout .= "     ecmdFunctionTimer(myTcount,ECMD_TMR_FUNCTIONOUT,\"$orgfuncname\");\n";
                    $" = ","; # So we put commas between the tokens in argnames
		    $printout .= "     ecmdFunctionParmPrinter(myTcount,ECMD_FPP_FUNCTIONOUT,\"$type $orgfuncname(@argnames)\",args);\n";
		    #	    
		    $printout .= "   }\n";
		} # end if there are no args
	    } # end if its not ecmdFunctionParmPrinter 

	    $printout .= "#endif\n\n";
        }

	$printout .= "  return rc;\n\n" unless ($type_flag == $VOID);

	$printout .= "}\n\n";

    }

}
close IN;

if ($ARGV[1] =~ /DllCapi.H/ || $genAll) {
  # So we don't error at the end
  $didFile = 1;

  open OUT, ">${curdir}/$ARGV[0]DllCapi.H" or die $!;
  print OUT "/* The following has been auto-generated by makedll.pl */\n";

  print OUT "#ifndef $ARGV[0]DllCapi_H\n";
  print OUT "#define $ARGV[0]DllCapi_H\n\n";

  print OUT "#include <inttypes.h>\n";
  print OUT "#include <vector>\n";
  print OUT "#include <string>\n\n";

  print OUT "#include <ecmdDefines.H>\n";
  print OUT "#include <ecmdStructs.H>\n";
  print OUT "#include <ecmdReturnCodes.H>\n";
  print OUT "#include <ecmdDataBuffer.H>\n\n\n";
  if ($ARGV[0] ne "ecmd") {
    print OUT "#include <$ARGV[0]Structs.H>\n";
  }

  print OUT "extern \"C\" {\n\n";

  if ($ARGV[0] eq "ecmd") {

    print OUT "/* Dll Common load function - verifies version */\n";
    print OUT "uint32_t dllLoadDll (const char * i_version, uint32_t debugLevel);\n";
    print OUT "/* Dll Specific load function - used by Cronus/GFW to init variables/object models*/\n";
    print OUT "uint32_t dllInitDll ();\n\n";
    print OUT "/* Dll Common unload function */\n";
    print OUT "uint32_t dllUnloadDll ();\n";
    print OUT "/* Dll Specific unload function - deallocates variables/object models*/\n";
    print OUT "uint32_t dllFreeDll();\n\n";
    print OUT "/* Dll version check function */\n";
    print OUT "uint32_t dllCheckDllVersion (const char* options);\n";
    print OUT "/* Dll Common Command Line Args Function*/\n";
    print OUT "uint32_t dllCommonCommandArgs(int*  io_argc, char** io_argv[]);\n";
    print OUT "/* Dll Specific Command Line Args Function*/\n";
    print OUT "uint32_t dllSpecificCommandArgs(int*  io_argc, char** io_argv[]);\n\n";

  } else {
    print OUT "/* Extension initialization function - verifies version */\n";
    print OUT "uint32_t dll".ucfirst($ARGV[0])."InitExtension(const char * i_version);\n\n";
    print OUT "/* Extension Specific load function - used by Cronus/GFW to see if extension is supported */\n";
    print OUT "uint32_t dll".ucfirst($ARGV[0])."InitExtensionInPlugin();\n\n";
  }

  print OUT $dllCapiOut;

  print OUT "} //extern C\n\n";
  print OUT "#endif\n";
  print OUT "/* The previous has been auto-generated by makedll.pl */\n";

  close OUT;  #ecmdDllCapi.H
}

if ($ARGV[1] =~ /ClientEnums.H/ || $genAll) {
  # So we don't error at the end
  $didFile = 1;

  open OUT, ">${curdir}/$ARGV[0]ClientEnums.H" or die $!;

  print OUT "/* The following has been auto-generated by makedll.pl */\n\n";
  print OUT "#ifndef $ARGV[0]ClientEnums_H\n";
  print OUT "#define $ARGV[0]ClientEnums_H\n\n";
  print OUT "#ifndef ECMD_STATIC_FUNCTIONS\n";

  if ($ARGV[0] eq "ecmd") {
    push @enumtable, "ECMD_COMMANDARGS"; # This function is handled specially because it is renamed on the other side

  }
  push @enumtable, uc($ARGV[0])."_NUMFUNCTIONS";


  $" = ",\n";
  print OUT "/* These are used to lookup cached functions symbols */\n";
  print OUT "typedef enum {\n@enumtable\n} $ARGV[0]FunctionIndex_t;\n\n";
  print OUT "#endif\n\n";
  print OUT "#endif\n";
  $" = " ";

  close OUT;  #ecmdClientEnums.H
}

if ($ARGV[1] =~ /ClientCapiFunc.C/ || $genAll) {
  # So we don't error at the end
  $didFile = 1;

  open OUT, ">${curdir}/$ARGV[0]ClientCapiFunc.C" or die $!;

  print OUT "/* The following has been auto-generated by makedll.pl */\n\n";
  print OUT "#include <stdio.h>\n\n";
  if ($ARGV[0] ne "ecmd") {
    print OUT "#include <ecmdClientCapi.H>\n";
  }
  print OUT "#include <ecmdSharedUtils.H>\n";
  print OUT "#include <$ARGV[0]ClientCapi.H>\n";
  print OUT "#ifndef ECMD_STATIC_FUNCTIONS\n";
  print OUT "#include <$ARGV[0]ClientEnums.H>\n\n\n";
  print OUT "#endif\n\n";

  print OUT "#include <ecmdUtils.H>\n\n";

  print OUT "static const char ECMD_DLL_NOT_LOADED_ERROR[] = \": eCMD Function called before DLL has been loaded\\n\";\n";
  print OUT "static const char ECMD_UNABLE_TO_FIND_FUNCTION_ERROR[] = \": Unable to find function, must be an invalid DLL - program aborting\\n\";\n";
  print OUT "#ifndef ECMD_STATIC_FUNCTIONS\n";
  print OUT "\n #include <dlfcn.h>\n\n";

  if ($ARGV[0] eq "ecmd") {
    print OUT " void * dlHandle = NULL;\n";
    print OUT " void * DllFnTable[".uc($ARGV[0])."_NUMFUNCTIONS];\n";
  } else {
    print OUT "/* This is from ecmdClientCapiFunc.C */\n";
    print OUT " extern void * dlHandle;\n";
    # If enumtable only has one entry this means this extension doesn't have any functions in it
    if ($#enumtable == 0) {
      print OUT " void * $ARGV[0]DllFnTable[1 /* NO FUNCTIONS DEFAULT TO 1 - ".uc($ARGV[0])."_NUMFUNCTIONS */];\n";
    } else {
      print OUT " void * $ARGV[0]DllFnTable[".uc($ARGV[0])."_NUMFUNCTIONS];\n";
    }

  }       

  print OUT "\n#else\n\n";

  print OUT " #include <$ARGV[0]DllCapi.H>\n\n";

  print OUT "#endif\n\n\n";

  if ($ARGV[0] ne "ecmd") {
    print OUT "/* Our initialization flag */\n";
    print OUT " bool $ARGV[0]Initialized = false;\n";
  }

  print OUT "#ifndef ECMD_STRIP_DEBUG\n";
  print OUT "extern int ecmdClientDebug;\n";
  print OUT "extern int fppCallCount;\n";
  print OUT "extern bool ecmdDebugOutput;\n";
  print OUT "#endif\n\n\n";

  print OUT $printout;

  print OUT "/* The previous has been auto-generated by makedll.pl */\n";

  close OUT;  #ecmdClientCapiFunc.C
}

if (!$didFile) {
  printf("ERROR: Unknown file type \"$ARGV[1]\" passed in!\n");
}
