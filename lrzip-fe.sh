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
		--cr-wrap --form \
		"Expert Options\nAdvanced Users Only\nDefault Values used if blank" \
		0 0 0 \
		"                    Show Hash (Y/N): " 1 1 "$tHASH "      1 39 5 4 \
		"             Number of Threads (##): " 2 1 "$tTHREADS "   2 39 5 4 \
		"    Disable Threshold Testing (Y/N): " 3 1 "$tTHRESHOLD " 3 39 5 4 \
		"                   Nice Value (###): " 4 1 "$tNICE "      4 39 5 4 \
		"         Maximum Ram x 100Mb (####): " 5 1 "$tMAXRAM "    5 39 5 5 \
		"  Memory Window Size x 100Mb (####): " 6 1 "$tWINDOW "    6 39 5 5 \
		"  Unlimited Ram Use (CAREFUL) (Y/N): " 7 1 "$tUNLIMITED " 7 39 5 4 \
		"                      Encrypt (Y/N): " 8 1 "$tENCRYPT "   8 39 5 4 \
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

get_filter()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Pre-Compression Filter" \
		--no-tags --radiolist "Select Filter" \
		0 0 0 \
		-- \
		"--x86" "x86" "off" \
		"--arm" "arm" "off" \
		"--armt" "armt" "off" \
		"--ppc" "ppc" "off" \
		"--sparc" "sparc" "off" \
		"--ia64" "ia64" "off" \
		"--delta=" "delta" "off" \
		2>/tmp/lfilter.dia
	check_error
	FILTER=$(cat /tmp/lfilter.dia)
	if [ "x$FILTER" == "x--delta=" ] ; then
		dialog --clear --inputbox "Enter Delta Value:" \
			0 0 "1" 2>/tmp/ldelta.dia
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
		--no-tags --radiolist "Compression Level" \
		0 0 0 \
		--  \
		"--level=1" "Level 1" "off" \
		"--level=2" "Level 2" "off" \
		"--level=3" "Level 3" "off" \
		"--level=4" "Level 4" "off" \
		"--level=5" "Level 5" "off" \
		"--level=6" "Level 6" "off" \
		"--level=7" "Level 7 (default)" "on" \
		"--level=8" "Level 8" "off" \
		"--level=9" "Level 9" "off" \
		2>/tmp/llevel.dia
	check_error
	LEVEL=$(</tmp/llevel.dia)
}

get_method()
{
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Compression Method" \
		--no-tags --radiolist "Compression Method" \
		0 0 0 \
		-- \
		"--lzma" "lzma (default)" "on" \
		"--bzip" "bzip" "off" \
		"--gzip" "gzip" "off" \
		"--lzo" "lzo" "off" \
		"--rzip" "rzip" "off" \
		"--zpaq" "zpaq" "off" \
		2>/tmp/lmethod.dia
	check_error
	METHOD=$(</tmp/lmethod.dia)
}

get_output()
{
	# use temp variables for dialog and add command at end
	dialog --backtitle "$COMMANDLINE" \
		--title "$PROG: Output Options" \
		--cr-wrap --form \
		"Set either Output Directory (-O) \n
- OR - \n
Output Filename (-o)\n
-S sets Filename Suffix" \
0 0 0 \
	"Output Directory (-O): " 1 1 "$tOUTDIR " 1 25 64 64 \
	"Output Filename (-o): "  2 1 "$tOUTNAME " 2 25 64 64 \
	"Filename Suffix (-S): "  3 1 "$tSUFFIX " 3 25 16 16 \
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
		--no-tags --radiolist "Verbosity" \
		0 0 0 \
		-- \
		"--verbose" "Verbose" "off" \
		"--verbose --verbose" "Maximum Verbosity" "off" \
		"--progress" "Show Progress" "on" \
		"--quiet" "Silent. Show no progress" "off" \
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
