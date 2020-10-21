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

# return option from file
# arguments $1 = filename
# returns short of long option
return_sl_option()
{
	# default to long
	local SL_FIELD=2
	# if 0 length file or non-existent
	[ ! -s "$1" -o ! -e "$1" ] && return -1
	[ "$SHORTLONG" == "SHORT" ] && SL_FIELD=1

	RETURN_VAL=$(cat "$1" | cut -f $SL_FIELD -d'|')
}

# return either short or long option
# $1 = short option
# $2 = long option
return_sl_option_value()
{
	if [ "$SHORTLONG" == "LONG" ] ; then
		RETURN_VAL="$2"
	else
		RETURN_VAL="$1"
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
		"                    Show Hash (Y/N): " 1 1 "$tHASH "      1 39 6 4 "Show MD5 Hash Integrity Information" \
		"             Number of Threads (##): " 2 1 "$tTHREADS "   2 39 6 4 "Set processor count to override number of threads" \
		"    Disable Threshold Testing (Y/N): " 3 1 "$tTHRESHOLD " 3 39 6 4 "Disable LZO Compressibility Testing" \
		"                   Nice Value (###): " 4 1 "$tNICE "      4 39 6 4 "Set Nice to value ###" \
		"         Maximum Ram x 100Mb (####): " 5 1 "$tMAXRAM "    5 39 6 5 "Override detected system ram to ### (in 100s of MB)" \
		"  Memory Window Size x 100Mb (####): " 6 1 "$tWINDOW "    6 39 6 5 "Override heuristically detected compression window size (in 100s of MB)" \
		"  Unlimited Ram Use (CAREFUL) (Y/N): " 7 1 "$tUNLIMITED " 7 39 6 4 "Use Unlimited window size beyond ram size. MUCH SLOWER" \
		"                      Encrypt (Y/N): " 8 1 "$tENCRYPT "   8 39 6 4 "Password protect lrzip file" \
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
				if [ "$tHASH" == "Y" -o "$tHASH" == "y" ] ; then
					return_sl_option_value "H" "--hash"
					HASH="$RETURN_VAL"
				fi
				;;
			2) tTHREADS=$TMPVAR
				if [ ${#tTHREADS} -gt 0 ] ; then
					return_sl_option_value "p $tTHREADS" "--threads=$tTHREADS"
					THREADS="$RETURN_VAL"
				fi
				;;
			3) tTHRESHOLD=$TMPVAR
				if [ "$tTHRESHOLD" == "Y" -o "$tTHRESHOLD" == "y" ] ; then
					return_sl_option_value "T" "--threshold"
					THRESHOLD="$RETURN_VAL"
				fi
				;;
			4) tNICE=$TMPVAR
				if [ ${#tNICE} -gt 0 ] ; then
					return_sl_option_value "N $tNICE" "--nice-level=$tNICE"
					NICE="$RETURN_VAL"
				fi
				;;
			5) tMAXRAM=$TMPVAR
				if [ ${#tMAXRAM} -gt 0 ] ; then
					return_sl_option_value "m $tMAXRAM" "--maxram=$tMAXRAM"
					MAXRAM="$RETURN_VAL"
				fi
				;;
			6) tWINDOW=$TMPVAR
				if [ ${#tWINDOW} -gt 0 ] ; then
					return_sl_option_value "w $tWINDOW" "--window=$tWINDOW"
					WINDOW="$RETURN_VAL"
				fi
				;;
			7) tUNLIMITED=$TMPVAR
				if [ "$tUNLIMITED" == "Y" -o "$tUNLIMITED" == "y" ] ; then
					return_sl_option_value "U" "--unlimited"
					UNLIMITED="$RETURN_VAL"
				fi
				;;
			8) tENCRYPT=$TMPVAR
				if [ "$tENCRYPT" == "Y" -o "$tENCRYPT" == "y" ] ; then
					return_sl_option_value "e" "--encrypt"
					ENCRYPT="$RETURN_VAL"
				fi
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
		"f|--force" "Force Overwrite" "$tFORCE" "Overwrite output file" \
		"D|--delete" "Delete Source File after work" "$tDELETE" "Delete input file after compression/decompression" \
		"K|--keep-broken" "Keep broken output file" "$tKEEP" "Keep broken file if lrzip is interrupted or other error" \
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
	SL_FIELD=2
	[ $SHORTLONG == "SHORT" ] && SL_FIELD=1
	for TMPVAR in $(</tmp/lfilehandling.dia)
	do
		RETURN_VAL=$(echo $TMPVAR | cut -f $SL_FIELD -d'|')
		case $TMPVAR in
			"f|--force" )
				tFORCE="on"
				FORCE=$RETURN_VAL
				;;
			"D|--delete" )
				tDELETE="on"
				DELETE=$RETURN_VAL
				;;
			"K|--keep-broken" )
				tKEEP="on"
				KEEP=$RETURN_VAL
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
		"L 1|--level=1" "Level 1" "off" "Set Compression Level 1 for $METHOD" \
		"L 2|--level=2" "Level 2" "off" "Set Compression Level 2 for $METHOD" \
		"L 3|--level=3" "Level 3" "off" "Set Compression Level 3 for $METHOD" \
		"L 4|--level=4" "Level 4" "off" "Set Compression Level 4 for $METHOD" \
		"L 5|--level=5" "Level 5" "off" "Set Compression Level 5 for $METHOD" \
		"L 6|--level=6" "Level 6" "off" "Set Compression Level 6 for $METHOD" \
		"L 7|--level=7" "Level 7 (default)" "on" "Set Compression Level 7 for $METHOD" \
		"L 8|--level=8" "Level 8" "off" "Set Compression Level 8 for $METHOD" \
		"L 9|--level=9" "Level 9" "off" "Set Compression Level 9 for $METHOD" \
		2>/tmp/llevel.dia
	check_error
	return_sl_option "/tmp/llevel.dia"
	LEVEL=$RETURN_VAL
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
		"|--lzma" "lzma (default)" "on" "Default LZMA Compression" \
		"b|--bzip" "bzip" "off" "BZIP2 Compression" \
		"g|--gzip" "gzip" "off" "GZIP Compression" \
		"l|--lzo" "lzo" "off" "LZO Compression" \
		"n|--rzip" "rzip" "off" "Do NOT Compress. Just pre-process using RZIP (Fastest)." \
		"z|--zpaq" "zpaq" "off" "Use ZPAQ Compression (Slowest)." \
		2>/tmp/lmethod.dia
	check_error
	return_sl_option "/tmp/lmethod.dia"
	METHOD=$RETURN_VAL
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
	if [ ${#tOUTDIR} -gt 0 ] ; then
		return_sl_option_value "O $tOUTDIR" "--outdir=$tOUTDIR"
		OUTDIR="$RETURN_VAL"
	elif [ ${#tOUTNAME} -gt 0 ] ; then
		return_sl_option_value "o $tOUTNAME" "--outname=$tOUTNAMER"
		OUTNAME="$RETURN_VAL"
	elif [ ${#tSUFFIX} -gt 0 ] ; then
		return_sl_option_value "S $tSUFFIX" "--suffix=$tSUFFIX"
		SUFFIX="$RETURN_VAL"
	fi
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
		"v|--verbose" "Verbose" "off" "Show lrzip settings and progress prior to compression/decompression" \
		"vv|--verbose --verbose" "Maximum Verbosity" "off" "Show compression/decompression/extra info on lrzip execugtion in addition to -v option" \
		"P|--progress" "Show Progress" "on" "Only show progress, no other verbose options on compression/decompression" \
		"q|--quiet" "Silent. Show no progress" "off" "Be quiet and show nothing on compression/decompression" \
		2>/tmp/lverbosity.dia
	check_error
	return_sl_option "/tmp/lverbosity.dia"
	VERBOSITY=$RETURN_VAL
}


fillcommandline()
{
	COMMANDLINE="lrzip"
	if [ "$SHORTLONG" == "LONG" ]; then
		[ ! -z $LMODE ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $LMODE")
		[ ! -z $METHOD ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $METHOD")
		[ ! -z $LEVEL ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $LEVEL")
		[ ! -z $FILTER ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $FILTER")
		[ ! -z $DELTA ] 	&& COMMANDLINE=$(echo "$COMMANDLINE$DELTA")
		[ ! -z $VERBOSITY ]	&& COMMANDLINE=$(echo "$COMMANDLINE $VERBOSITY")
		[ ! -z $FORCE ]		&& COMMANDLINE=$(echo "$COMMANDLINE $FORCE")
		[ ! -z $DELETE ]	&& COMMANDLINE=$(echo "$COMMANDLINE $DELETE")
		[ ! -z $KEEP ]		&& COMMANDLINE=$(echo "$COMMANDLINE $KEEP")
		[ ! -z $OUTDIR ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $OUTDIR")
		[ ! -z $OUTNAME ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $OUTNANE")
		[ ! -z $SUFFIX ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $SUFFIX")
		[ ! -z $HASH ]		&& COMMANDLINE=$(echo "$COMMANDLINE $HASH")
		[ ! -z $THREADS ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $THREADS")
		[ ! -z $THRESHOLD ]	&& COMMANDLINE=$(echo "$COMMANDLINE $THRESHOLD")
		[ ! -z $NICE ]		&& COMMANDLINE=$(echo "$COMMANDLINE $NICE")
		[ ! -z $MAXRAM ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $MAXRAM")
		[ ! -z $WINDOW ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $WINDOW")
		[ ! -z $UNLIMITED ]	&& COMMANDLINE=$(echo "$COMMANDLINE $UNLIMITED")
		[ ! -z $ENCRYPT ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $ENCRYPT")
		[ ! -z $FILE ]		&& COMMANDLINE=$(echo "$COMMANDLINE $FILE")
	else
		COMMANDLINE=$(echo "$COMMANDLINE ")
		let firsttime=0
		if [ ! -z $LMODE ] ; then
			COMMANDLINE=$(echo "$COMMANDLINE-$LMODE")
			firsttime=1
		fi
		if [ ! -z $METHOD ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$METHOD")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$METHOD")
				let firsttime=1
			fi
		fi
		if [ ! -z $VERBOSITY ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$VERBOSITY")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$VERBOSITY")
				let firsttime=1
			fi
		fi
		if [ ! -z $FORCE ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$FORCE")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$FORCE")
				let firsttime=1
			fi
		fi
		if [ ! -z $DELETE ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$DELETE")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$DELETE")
				let firsttime=1
			fi
		fi
		if [ ! -z $KEEP ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$KEEP")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$KEEP")
				let firsttime=1
			fi
		fi
		if [ ! -z $HASH ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$HASH")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$HASH")
				let firsttime=1
			fi
		fi
		if [ ! -z $UNLIMITED ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$UNLIMITED")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$UNLIMITED")
				let firsttime=1
			fi
		fi
		if [ ! -z $ENCRYPT ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$ENCRYPT")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$ENCRYPT")
				let firsttime=1
			fi
		fi
		if [ ! -z $THRESHOLD ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE=$(echo "$COMMANDLINE$THRESHOLD")
			else
				COMMANDLINE=$(echo "$COMMANDLINE-$THRESHOLD")
				let firsttime=1
			fi
		fi
		[ ! -z $LEVEL ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$LEVEL")
		[ ! -z $OUTDIR ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$OUTDIR")
		[ ! -z $OUTNAME ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$OUTNANE")
		[ ! -z $SUFFIX ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$SUFFIX")
		[ ! -z $THREADS ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$THREADS")
		[ ! -z $FILTER ] 	&& COMMANDLINE=$(echo "$COMMANDLINE $FILTER")
		[ ! -z $DELTA ] 	&& COMMANDLINE=$(echo "$COMMANDLINE$DELTA")
		[ ! -z $NICE ]		&& COMMANDLINE=$(echo "$COMMANDLINE -$NICE")
		[ ! -z $MAXRAM ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$MAXRAM")
		[ ! -z $WINDOW ] 	&& COMMANDLINE=$(echo "$COMMANDLINE -$WINDOW")
		[ ! -z $FILE ]		&& COMMANDLINE=$(echo "$COMMANDLINE $FILE")
	fi
}

# Main program starts here

# set some globals
RETCODE=$DIALOG_EXTRA
SHORTLONG="LONG"

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
RETURN_VAL=

if [ $SHORTLONG == "LONG" ] ; then
	LOCALSL="SHORT"
else
	LOCALSL="LONG"
fi

dialog --title "Welcome to $PROG" \
	--no-tags \
	--extra-button --extra-label "Toggle $LOCALSL Commands" \
	--ok-label "Select lrzip Mode" \
	--menu "Copyright 2020 Peter Hyman\nA front-end for lrzip\n\
Choose an lrzip Action" \
	0 0 0 \
	"" "Compress a file" \
	"d|--decompress" "Decompress a file"  \
	"t|--test" "Test file integrityt" \
	"i|--info" "Info - show file and stream block info" \
	2>/tmp/lmode.dia

check_error

#TOGGLE short or long command line options
if [ $RETCODE -eq $DIALOG_EXTRA ] ; then
	if [ $SHORTLONG == "LONG" ] ; then
		SHORTLONG="SHORT"
	else
		SHORTLONG="LONG"
	fi
	continue
fi

return_sl_option "/tmp/lmode.dia"
[ $? -eq -1 ] && RETURN_VAL=
LMODE=$RETURN_VAL

if [ -z $LMODE ]; then
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
elif [ x"$LMODE" == "x--decompress" -o x"$LMODE" == "xd" ] ; then
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
elif [ x"$LMODE" == "x--test" -o x"$LMODE" == "x--info" -o x"$LMODE" == "xt" -o x"$LMODE" == "xi" ] ; then
	# Test or Info
	[ $LMODE == "--test" -o $LMODE == "t" ] && MODE="Test"
	[ $LMODE == "--info" -o $LMODE == "i" ] && MODE="Info"
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
