#!/bin/sh

# lrzip dialog front end
# based on lrzip 0.7x+
# Peter Hyman, pete@peterhyman.com
# Placed in the public domain
# no warranties, restrictions
# just attribution appreciated

# Some constants
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_EXTRA=3
DIALOG_ESC=255
SAVEIFS=$IFS

PROG=$(basename $0)

# get screen dimensions and center values
# in case we need to manipulate boxes
max=$(dialog --print-maxsize --output-fd 1)
# format MaxSize: YYY, XXX
screen_y=$(echo $max | cut -f2 -d' ' | cut -f1 -d',') # after space, before ,
screen_x=$(echo $max | cut -f2 -d',' | cut -f2 -d' ') # after comma, after space
center_y=$((screen_y/2))
center_x=$((screen_x/2))

check_error()
{
	RETCODE=$?
	if [ $RETCODE -ne $DIALOG_OK -a $RETCODE -ne $DIALOG_EXTRA ] ; then
		dialog --infobox \
		"Exiting due to cancel.\nCommand line so far: \n$COMMANDLINE" 0 0
		
		exit -1
	fi
}

get_advanced()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Advanced lrzip options" \
		--cr-wrap \
		--item-help \
		--form \
		"Expert Options\nAdvanced Users Only\nDefault Values used if blank" \
		0 0 0 \
		"                    Show Hash (Y/N): " 1 1 "$tHASH "      1 39 5 4 "Show MD5 Hash Integrity Information" \
		"             Number of Threads (##): " 2 1 "$tTHREADS "   2 39 5 4 "Set processor count to override number of threads" \
		"    Disable Threshold Testing (Y/N): " 3 1 "$tTHRESHOLD " 3 39 5 4 "Disable LZO Compressibility Testing" \
		"                   Nice Value (###): " 4 1 "$tNICE "      4 39 5 4 "Set Nice to value ###" \
		"         Maximum Ram x 100Mb (####): " 5 1 "$tMAXRAM "    5 39 5 5 "Override detected system ram to ### (in 100s of MB)" \
		"  Memory Window Size x 100Mb (####): " 6 1 "$tWINDOW "    6 39 5 5 "Override heuristically detected compression window size (in 100s of MB)" \
		"  Unlimited Ram Use (CAREFUL) (Y/N): " 7 1 "$tUNLIMITED " 7 39 5 4 "Use Unlimited window size beyond ram size. MUCH SLOWER" \
		"                      Encrypt (Y/N): " 8 1 "$tENCRYPT "   8 39 5 4 "Password protect lrzip file" \
		2>/tmp/ladvanced.dia
	check_error
# make newline field separator
	IFS=$'\xA'
	local i=0
	for TMPVAR in $(</tmp/ladvanced.dia)
	do
		TMPVAR="${TMPVAR/% /}" # remove trailing whitespace
		let i=i+1
		case $i in
			1) tHASH=$TMPVAR
				[ "$tHASH" == "Y" -o "$tHASH" == "y" ] && HASH="--hash"
				;;
			2) tTHREADS=$TMPVAR
				[ ${#tTHREADS} -gt 0 ] && THREADS="--threads="$tTHREADS
				;;
			3) tTHRESHOLD=$TMPVAR
				[ "$tTHRESHOLD" == "Y" -o "$tTHRESHOLD" == "y" ] && THRESHOLD="--threshold"
				;;
			4) tNICE=$TMPVAR
				[ ${#tNICE} -gt 0 ] && NICE="--nice "$tNICE
				;;
			5) tMAXRAM=$TMPVAR
				[ ${#tMAXRAM} -gt 0 ] && MAXRAM="--maxram="$tMAXRAM
				;;
			6) tWINDOW=$TMPVAR
				[ ${#tWINDOW} -gt 0 ] && WINDOW="--window="$tWINDOW
				;;
			7) tUNLIMITED=$TMPVAR
				[ "$tUNLIMITED" == "Y" -o "$tUNLIMITED" == "y" ] && UNLIMITED="--unlimited"
				;;
			8) tENCRYPT=$TMPVAR
				[ "$tENCRYPT" == "Y" -o "$tENCRYPT" == "y" ] && ENCRYPT="--encrypt"
				;;
			*) break;
				;;
		esac
	done
}

get_file()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: File Selection" \
		--fselect ./ 20 50 \
		2>/tmp/lfile.dia
	check_error
	FILE=$(</tmp/lfile.dia)
}

get_file_handling()
{
	[ x"$tFORCE" == "x" ]	&& tFORCE="off"
	[ x"$tDELETE" == "x" ]	&& tDELETE="off"
	[ x"$tKEEP" == "x" ]	&& tKEEP="off"
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: File Handling" \
		--no-tags \
		--separate-output \
		--item-help \
		--checklist "File Handling Options" \
		0 0 0 \
		--  \
		"--force" "Force Overwrite" "$tFORCE" "Overwrite output file" \
		"--delete" "Delete Source File after work" "$tDELETE" "Delete input file after compression/decompression" \
		"--keep-broken" "Keep broken output file" "$tKEEP" "Keep broken file if lrzip is interrupted or other error" \
		2>/tmp/lfilehandling.dia
	check_error

# make newline field separator
# clear variables
	IFS=$'\xA'
	tFORCE=
	tDELETE=
	tKEEP=
	FORCE=
	DELETE=
	KEEP=
	for TMPVAR in $(</tmp/lfilehandling.dia)
	do
		case $TMPVAR in
			"--force" )
				tFORCE="on"
				FORCE=$TMPVAR
				;;
			"--delete" )
				tDELETE="on"
				DELETE=$TMPVAR
				;;
			"--keep-broken" )
				tKEEP="on"
				KEEP=$TMPVAR
				;;
			* )
				break
				;;

		esac
	done
}

get_filter()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Pre-Compression Filter" \
		--no-tags \
		--item-help \
		--radiolist "Select Filter" \
		0 0 0 \
		-- \
		"--x86" "x86" "off" "Use x86 code pre-compression filter" \
		"--arm" "arm" "off" "Use arm code pre-compression filter" \
		"--armt" "armt" "off" "Use armt code pre-compression filter" \
		"--ppc" "ppc" "off" "Use ppc code pre-compression filter" \
		"--sparc" "sparc" "off" "Use sparc code pre-compression filter" \
		"--ia64" "ia64" "off" "Use ia64 code pre-compression filter" \
		"--delta=" "delta" "off" "Use delta code pre-compression filter. Delta offset value to be input next." \
		2>/tmp/lfilter.dia
	check_error
	FILTER=$(cat /tmp/lfilter.dia)
	if [ "x$FILTER" == "x--delta=" ] ; then
		dialog --clear \
			--title "Delta Value" \
			--inputbox "Enter Delta Filter Offset Value:" 0 41 "1" \
			2>/tmp/ldelta.dia
		check_error
		DELTA=$(</tmp/ldelta.dia)
	else
		DELTA=
	fi
}

get_level()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Compression Level" \
		--no-tags \
		--item-help \
		--radiolist "Compression Level" \
		0 0 0 \
		--  \
		"--level=1" "Level 1" "off" "Set Compression Level 1 for $METHOD" \
		"--level=2" "Level 2" "off" "Set Compression Level 2 for $METHOD" \
		"--level=3" "Level 3" "off" "Set Compression Level 3 for $METHOD" \
		"--level=4" "Level 4" "off" "Set Compression Level 4 for $METHOD" \
		"--level=5" "Level 5" "off" "Set Compression Level 5 for $METHOD" \
		"--level=6" "Level 6" "off" "Set Compression Level 6 for $METHOD" \
		"--level=7" "Level 7 (default)" "on" "Set Compression Level 7 for $METHOD" \
		"--level=8" "Level 8" "off" "Set Compression Level 8 for $METHOD" \
		"--level=9" "Level 9" "off" "Set Compression Level 9 for $METHOD" \
		2>/tmp/llevel.dia
	check_error
	LEVEL=$(</tmp/llevel.dia)
}

get_method()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Compression Method" \
		--no-tags \
		--item-help \
		--radiolist "Compression Method" \
		0 0 0 \
		-- \
		"--lzma" "lzma (default)" "on" "Default LZMA Compression" \
		"--bzip" "bzip" "off" "BZIP2 Compression" \
		"--gzip" "gzip" "off" "GZIP Compression" \
		"--lzo" "lzo" "off" "LZO Compression" \
		"--rzip" "rzip" "off" "Do NOT Compress. Just pre-process using RZIP (Fastest)." \
		"--zpaq" "zpaq" "off" "Use ZPAQ Compression (Slowest)." \
		2>/tmp/lmethod.dia
	check_error
	METHOD=$(</tmp/lmethod.dia)
}

get_output()
{
	# use temp variables for dialog and add command at end
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Output Options" \
		--cr-wrap \
		--item-help \
		--form \
		"Set either Output Directory (-O) \n
- OR - \n
Output Filename (-o)\n
-S sets Filename Suffix" \
		0 0 0 \
		"Output Directory (-O): " 1 1 "$tOUTDIR " 1 25 64 64 "Compressed/Decompressed file will be written to Output Directory. Cannot be combined with Output Filename (-o)." \
		"Output Filename (-o): "  2 1 "$tOUTNAME " 2 25 64 64 "Set Output Filename. Cannot be combined with Output Directory (-O)." \
		"Filename Suffix (-S): "  3 1 "$tSUFFIX " 3 25 16 16 "Set Filename Suffix (ex. .mysffix) instead of or in addition to .lrz." \
	2>/tmp/loutopts.dia
	check_error

# make newline field separator
	IFS=$'\xA'
	local i=0
	for TMPVAR in $(</tmp/loutopts.dia)
	do
		TMPVAR="${TMPVAR/% /}" # remove trailing whitespace
		let i=i+1
		case $i in
			1) tOUTDIR=$TMPVAR;;
			2) tOUTNAME=$TMPVAR;;
			3) tSUFFIX=$TMPVAR;;
		esac
	done

	if [ ${#tOUTDIR} -gt 0 -a ${#tOUTNAME} -gt 0 ] ; then
	       # ERROR
		dialog --title "ERROR!" \
	 		--msgbox "Cannot specify both an\n\
Output Directory: $tOUTDIR \n\
and an \n\
Output Filename: $tOUTNAME \n\
\n\
Clearing both" 0 0
		tOUTDIR=
		tOUTNAME=
		OUTDIR=
		OUTNAME=
	fi
	[ ${#tOUTDIR} -gt 0 ] 	&& OUTDIR="--outdir="$tOUTDIR
	[ ${#tOUTNAME} -gt 0 ] 	&& OUTNAME="--outname="$tOUTNAME
	[ ${#tSUFFIX} -gt 0 ] 	&& SUFFIX="--suffix="$tSUFFIX
# restore field separator
	IFS=$SAVEIFS
}

get_verbosity()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Verbosity" \
		--no-tags \
		--item-help \
		--radiolist "Verbosity" \
		0 0 0 \
		-- \
		"--verbose" "Verbose" "off" "Show lrzip settings and progress prior to compression/decompression" \
		"--verbose --verbose" "Maximum Verbosity" "off" "Show compression/decompression/extra info on lrzip execugtion in addition to -v option" \
		"--progress" "Show Progress" "on" "Only show progress, no other verbose options on compression/decompression" \
		"--quiet" "Silent. Show no progress" "off" "Be quiet and show nothing on compression/decompression" \
		2>/tmp/lverbosity.dia
	check_error
	VERBOSITY=$(</tmp/lverbosity.dia)
}

fillcommandline()
{
	COMMANDLINE="lrzip"
	[ x"$LMODE" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $LMODE")
	[ x"$METHOD" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $METHOD")
	[ x"$LEVEL" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $LEVEL")
	[ x"$FILTER" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $FILTER")
	[ x"$DELTA" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE$DELTA")
	[ x"$VERBOSITY" != "x" ] && COMMANDLINE=$(echo "$COMMANDLINE $VERBOSITY")
	[ x"$FORCE" != "x" ]	&& COMMANDLINE=$(echo "$COMMANDLINE $FORCE")
	[ x"$DELETE" != "x" ]	&& COMMANDLINE=$(echo "$COMMANDLINE $DELETE")
	[ x"$KEEP" != "x" ]	&& COMMANDLINE=$(echo "$COMMANDLINE $KEEP")
	[ x"$OUTDIR" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $OUTDIR")
	[ x"$OUTNAME" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $OUTNANE")
	[ x"$SUFFIX" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $SUFFIX")
	[ x"$HASH" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $HASH")
	[ x"$THREADS" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $THREADS")
	[ x"$THRESHOLD" != "x" ] && COMMANDLINE=$(echo "$COMMANDLINE $THRESHOLD")
	[ x"$NICE" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $NICE")
	[ x"$MAXRAM" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $MAXRAM")
	[ x"$WINDOW" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $WINDOW")
	[ x"$UNLIMITED" != "x" ] && COMMANDLINE=$(echo "$COMMANDLINE $UNLIMITED")
	[ x"$ENCRYPT" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $ENCRYPT")
	[ x"$FILE" != "x" ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $FILE")
}

# Main program starts here

RETCODE=$DIALOG_EXTRA

while [ $RETCODE -eq $DIALOG_EXTRA ]
do

# clear everything
LMODE=
METHOD=
LEVEL=
FILTER=
DELTA=
VERBOSITY=
FORCE=
DELETE=
KEEP=
OUTDIR=
OUTNAME=
SUFFIX=
FILE=
HASH=
THREADS=
THRESHOLD=
NICE=
MAXRAM=
WINDOW=
UNLIITED=
ENCRYPT=

dialog --title "Welcome to $PROG" \
	--no-tags \
--menu "Copyright 2020 Peter Hyman\nA front-end for lrzip\n\
Choose an lrzip Action" \
	0 0 0 \
	"" "Compress a file" \
	"--decompress" "Decompress a file"  \
	"--test" "Test file integrityt" \
	"--info" "Info - show file and stream block info" \
	2>/tmp/lmode.dia

check_error

LMODE=$(</tmp/lmode.dia)

if [ x$LMODE == "x" ]; then
	# Compress
	while (true)
	do
		fillcommandline
		dialog 	--clear --backtitle "$COMMANDLINE" \
			--title "$PROG: Compression Options" \
			--extra-button --extra-label "Restart" \
			--menu "Compression Menu" \
			0 0 0 \
			"FILE"		"File to Compress" \
			"METHOD"	"Compression Method" \
			"LEVEL"		"Compression Level" \
			"FILTER"	"Pre-Compression Filter" \
			"VERBOSITY"	"Verbose Options" \
			"FILE HANDLING" "Keep, Delete, Overwrite Files" \
			"OUTPUT"	"Output Options" \
			"ADVANCED"	"Advanced Compression Options" \
			"EXIT"		"Cancel" \
			2>/tmp/lrzip.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break

		MENU=$(</tmp/lrzip.dia)

		if [ "$MENU" == "FILE" ] ; then
			get_file;
		elif [ "$MENU" == "METHOD" ] ; then
			get_method;
		elif [ "$MENU" == "LEVEL" ] ; then
			get_level;
		elif [ "$MENU" == "FILTER" ] ; then
			get_filter;
		elif [ "$MENU" == "VERBOSITY" ] ; then
			get_verbosity;
		elif [ "$MENU" == "FILE HANDLING" ] ; then
			get_file_handling;
		elif [ "$MENU" == "OUTPUT" ] ; then
			get_output;
		elif [ "$MENU" == "ADVANCED" ] ; then
			get_advanced;
		elif [ "$MENU" == "EXIT" ] ; then
			break;
		fi
	done
# done Compress
elif [ x"$LMODE" == "x--decompress" ] ; then
	# Decompress
	while (true)
	do
		fillcommandline
		dialog 	--clear --backtitle "$COMMANDLINE" \
			--title "$PROG: Decompression Options" \
			--extra-button --extra-label "Restart" \
			--menu "Decompression Menu" \
			0 0 0 \
			"FILE"		"File to Decompress" \
			"VERBOSITY"	"Verbose Options" \
			"FILE HANDLING" "Keep, Delete, Overwrite Files" \
			"OUTPUT"	"Output Options" \
			"EXIT"		"Cancel" \
			2>/tmp/lrzip.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break
	MENU=$(</tmp/lrzip.dia)

		if [ "$MENU" == "FILE" ] ; then
			get_file;
		elif [ "$MENU" == "VERBOSITY" ] ; then
			get_verbosity;
		elif [ "$MENU" == "FILE HANDLING" ] ; then
			get_file_handling;
		elif [ "$MENU" == "OUTPUT" ] ; then
			get_output;
		elif [ "$MENU" == "EXIT" ] ; then
			break;
		fi
	done
# done Decompress
elif [ x"$LMODE" == "x--test" -o x"$LMODE" == "x--info" ] ; then
	# Test or Info
	[ $LMODE == "--test" ] && MODE="Test"
	[ $LMODE == "--info" ] && MODE="Info"
	while (true)
	do
		fillcommandline
		dialog 	--clear --backtitle "$COMMANDLINE" \
			--title "$PROG: $MODE Options" \
			--extra-button --extra-label "Restart" \
			--menu "$MODE Menu" \
			0 0 0 \
			"FILE"		"File to Decompress" \
			"VERBOSITY"	"Verbose Options" \
			"EXIT"		"Cancel" \
			2>/tmp/lrzip.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break
	MENU=$(</tmp/lrzip.dia)

		if [ "$MENU" == "FILE" ] ; then
			get_file;
		elif [ "$MENU" == "VERBOSITY" ] ; then
			get_verbosity;
		elif [ "$MENU" == "EXIT" ] ; then
			break;
		fi
	done
# done Test or Info
fi

done # main outer loop

dialog --infobox \
	"lrzip command line options have been set as follows\n\n\
	$COMMANDLINE\n" 0 0
