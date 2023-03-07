#!/bin/sh

# lrzip dialog front end
# based on lrzip 0.9x+
# Peter Hyman, pete@peterhyman.com
# Placed in the public domain
# no warranties, restrictions
# just attribution appreciated

# Third release version
VERSION=0.30

# is lrzip even here?
for i in lrzip-next lrzip
do
	if [ -x $(which $i) ] ; then
		LRZ=$i
		break;
	fi
done

if [ -z "$LRZ" ] ; then
	echo "lrzip-next or lrzip not found...Cannot continue!"
	exit 1
fi

# store help file
LRZIPHELPFILE=/tmp/$LRZ.help
$LRZ -h >$LRZIPHELPFILE 2>&1

# Some constants
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_EXTRA=3
DIALOG_ESC=255

PROG=$(basename $0)

# get screen dimensions and center values
# in case we need to manipulate boxes
max=$(dialog --print-maxsize --output-fd 1)
# format MaxSize: YYY, XXX
screen_y=$(echo $max | cut -f2 -d' ' | cut -f1 -d',') # after space, before ,
screen_x=$(echo $max | cut -f2 -d',' | cut -f2 -d' ') # after comma, after space
center_y=$((screen_y/2))
center_x=$((screen_x/2))
# for command output screens
if [ $screen_x -lt 80 ] ; then
	let width=$screen_x
else
	let width=80
fi
if [ $screen_y -lt 40 ] ; then
	let height=$screen_y
else
	let height=40
fi
# Show infobox on exit with build command line
# $1 = message to show
# $2 = error code
# this ends program
remove_tempfiles() {
	local i
	for i in $(ls /tmp/l*.dia)
	do
		rm -f "$i" 2>/dev/null
	done
}

show_command()
{
	# Format height and width based on length of commands and messages and exit mode
	local COMMANDLINELEN
	local BOXHEIGHT=6
	local MSGLEN=${#1}

	if [ ${#COMMANDLINE} -gt ${#TARCOMMANDLINE} ] ; then
		let COMMANDLINELEN=${#COMMANDLINE}+4
	else
		let COMMANDLINELEN=${#TARCOMMANDLINE}+4
	fi
	[ $COMMANDLINELEN -ge $screen_x ] && let COMMANDLINELEN=$screen_x-4
	[ $COMMANDLINELEN -lt $MSGLEN ] && let COMMANDLINELEN=$MSGLEN+5

	[ $2 -ne 0 ] && BOXHEIGHT=7

	dialog --infobox \
		"$1:\n\n$COMMANDLINE\n$TARCOMMANDLINE" $BOXHEIGHT $COMMANDLINELEN

	# file cleanup
	remove_tempfiles

	exit $2
}

check_error()
{
	RETCODE=$?
	[ $RETCODE -ne $DIALOG_OK -a $RETCODE -ne $DIALOG_EXTRA ] && \
		show_command "Exiting due to cancel.\nCommand line so far" -1
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
	[ "$SHORTLONG" = "SHORT" ] && SL_FIELD=1

	RETURN_VAL=$(cat "$1" | cut -f $SL_FIELD -d'|')
}

# return either short or long option
# $1 = short option
# $2 = long option
return_sl_option_value()
{
	if [ "$SHORTLONG" = "LONG" ] ; then
		RETURN_VAL="$2"
	else
		RETURN_VAL="$1"
	fi
}

get_comment()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: $LRZ Comment" \
		--cr-wrap \
		--item-help \
		--form \
		"Input plain text Comment for lrz file. 64 char max." \
		0 0 0 \
		"Comment: "	1 1 "$tCOMMENT "	1 11 65 64 "Comment for LRZ file" \
		2>/tmp/lcomment.dia
	check_error
	local IFS=$'\xA'
	TMPVAR=$(</tmp/lcomment.dia)
	TMPVAR="${TMPVAR/% /}"		# clear trailing spaces
	TMPVAR="${TMPVAR// /\\ }"	# escape spaces
	if [ ${#TMPVAR} -gt 0 ] ; then
		return_sl_option_value "C $TMPVAR" "--comment=$TMPVAR"
		COMMENT=$RETURN_VAL
	else
		COMMENT=
	fi
}

get_advanced()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: Advanced $LRZ options" \
		--cr-wrap \
		--item-help \
		--form \
		"Expert Options\nAdvanced Users Only\nDefault Values used if blank" \
		0 0 0 \
		"                    Show Hash (Y/N): "  1 1 "$tHASH "         1 39 2 2 "Show Hash Integrity Information (N)" \
		"                 Hash Method (1-13): "  2 1 "$tHASHMETHOD "   2 39 2 4 "1=MD5, 2=RIPEMD, 3=SHA256, 4=SHA384, 5=SHA512, 6=SHA3_256, 7=SHA3_512, 8=SHAKE128_16, 9=SHAKE128_32, 10=SHAKE128_64, 11=SHAKE256_16, 12=SHAKE256_32, 13=SHAKE256_64" \
		"             Number of Threads (##): "  3 1 "$tTHREADS "      3 39 6 4 "Set processor count to override number of threads" \
		"    Disable Threshold Testing (Y/N): "  4 1 "$tTHRESHOLD "    4 39 6 4 "Disable LZ4 Compressibility Testing (N)" \
		"           Threshold Percent (1-99): "  5 1 "$tTHRESHOLDPCT " 5 39 6 4 "Chunk Compressibility Percent (100)" \
		"                   Nice Value (###): "  6 1 "$tNICE "         6 39 6 4 "Set Nice to value ### (19)" \
		"         Maximum Ram x 100Mb (####): "  7 1 "$tMAXRAM "       7 39 6 5 "Override detected system ram to ### (in 100s of MB)" \
		"  Memory Window Size x 100Mb (####): "  8 1 "$tWINDOW "       8 39 6 5 "Override heuristically detected compression window size (in 100s of MB)" \
		"  Unlimited Ram Use (CAREFUL) (Y/N): "  9 1 "$tUNLIMITED "    9 39 6 4 "Use Unlimited window size beyond ram size. MUCH SLOWER" \
		"                      Encrypt (Y/N): " 10 1 "$tENCRYPT "     10 39 6 4 "Prompt for a Password to protect $LRZ file" \
		"            Encryption Method (1-2): " 11 1 "$tEMETHOD "     11 39 6 4 "Password Method: 1 = AES-128 (default), 2= AES-256"\
		2>/tmp/ladvanced.dia
	check_error
# make newline field separator local. No need to revert later.
	local IFS=$'\xA'
	local i=0
	for TMPVAR in $(</tmp/ladvanced.dia)
	do
		TMPVAR="${TMPVAR/% /}" # remove trailing whitespace
		let i=$i+1
		case $i in
			1) tHASH=$TMPVAR
				if [ "$tHASH" = "Y" -o "$tHASH" = "y" ] ; then
					return_sl_option_value "H" "--hash"
					HASH="$RETURN_VAL"
				fi
				;;
			2) tHASHMETHOD=$TMPVAR
				if [ ${#tHASHMETHOD} -gt 0 ] ; then
					return_sl_option_value "H$tHASHMETHOD" "--hash=$tHASHMETHOD"
					HASH=$RETURN_VAL
				fi
				;;
			3) tTHREADS=$TMPVAR
				if [ ${#tTHREADS} -gt 0 ] ; then
					return_sl_option_value "p $tTHREADS" "--threads=$tTHREADS"
					THREADS="$RETURN_VAL"
				fi
				;;
			4) tTHRESHOLD=$TMPVAR
				if [ "$tTHRESHOLD" = "Y" -o "$tTHRESHOLD" = "y" ] ; then
					return_sl_option_value "T" "--threshold"
					THRESHOLD="$RETURN_VAL"
				fi
				;;
			5) tTHRESHOLDPCT=$TMPVAR
				# Threshold Percent can't have a space since it's an optional value
				if [ ${tTHRESHOLDPCT} -ge 1 -a ${tTHRESHOLDPCT} -le 100 ] ; then
					return_sl_option_value "T$tTHRESHOLDPCT" "--threshold=$tTHRESHOLDPCT"
					THRESHOLDPCT="$RETURN_VAL"
				fi
				;;
			6) tNICE=$TMPVAR
				if [ ${#tNICE} -gt 0 ] ; then
					return_sl_option_value "N $tNICE" "--nice-level=$tNICE"
					NICE="$RETURN_VAL"
				fi
				;;
			7) tMAXRAM=$TMPVAR
				if [ ${#tMAXRAM} -gt 0 ] ; then
					return_sl_option_value "m $tMAXRAM" "--maxram=$tMAXRAM"
					MAXRAM="$RETURN_VAL"
				fi
				;;
			8) tWINDOW=$TMPVAR
				if [ ${#tWINDOW} -gt 0 ] ; then
					return_sl_option_value "w $tWINDOW" "--window=$tWINDOW"
					WINDOW="$RETURN_VAL"
				fi
				;;
			9) tUNLIMITED=$TMPVAR
				if [ "$tUNLIMITED" = "Y" -o "$tUNLIMITED" = "y" ] ; then
					return_sl_option_value "U" "--unlimited"
					UNLIMITED="$RETURN_VAL"
				fi
				;;
			10) tENCRYPT=$TMPVAR
				if [ "$tENCRYPT" = "Y" -o "$tENCRYPT" = "y" ] ; then
					return_sl_option_value "e" "--encrypt"
					ENCRYPT="$RETURN_VAL"
				fi
				;;
			11) tEMETHOD=$TMPVAR
				if [ ${#tEMETHOD} -gt 0 ] ; then
					return_sl_option_value "E $tEMETHOD" "--emethod=$tEMETHOD"
					EMETHOD=$RETURN_VAL
				fi
				;;
			*)
				break
				;;
		esac
	done
}

# set new directory
change_dir()
{
	local CHGDIR
	CHDIR=$(dialog --backtitle "Current Directory is: $PWD" \
		--title "$PROG: Set Directory" \
		--output-fd 1 \
		--dselect "$CHDIR" 20 50 )

	cd "$CHDIR"
}

get_file()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: File Selection" \
		--fselect "$tFILE" 20 50 \
		2>/tmp/lfile.dia
	check_error
	FILE=$(</tmp/lfile.dia)
	tFILE="$FILE"
}

get_file_handling()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: File Handling" \
		--no-tags \
		--separate-output \
		--item-help \
		--checklist "File Handling Options" \
		0 0 0 \
		--  \
		"f|--force" "Force Overwrite" "$tFORCE" "Overwrite output file" \
		"D|--delete" "Delete Source File after work" "$tDELETE" "Delete input file after compression/decompression" \
		"K|--keep-broken" "Keep broken output file" "$tKEEP" "Keep broken file if $LRZ is interrupted or other error" \
		2>/tmp/lfilehandling.dia
	check_error

# make newline field separator local. No need to revert later.
# clear variables
	local IFS=$'\xA'
	tFORCE=
	tDELETE=
	tKEEP=
	FORCE=
	DELETE=
	KEEP=
	SL_FIELD=2
	[ $SHORTLONG = "SHORT" ] && SL_FIELD=1
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
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: Pre-Compression Filter" \
		--no-tags \
		--item-help \
		--radiolist "Select Filter" \
		0 0 0 \
		-- \
		"--x86" "x86" "$tx86" "Use x86 code pre-compression filter" \
		"--arm" "arm" "$tARM" "Use arm code pre-compression filter" \
		"--armt" "armt" "$tARMT" "Use armt code pre-compression filter" \
		"--ppc" "ppc" "$tPPC" "Use ppc code pre-compression filter" \
		"--sparc" "sparc" "$tSPARC" "Use sparc code pre-compression filter" \
		"--ia64" "ia64" "$tia64" "Use ia64 code pre-compression filter" \
		"--delta=" "delta" "$tDELTA" "Use delta code pre-compression filter. Delta offset value to be input next." \
		2>/tmp/lfilter.dia
	check_error
	FILTER=$(cat /tmp/lfilter.dia)
	tx86="off"
	tARM="off"
	tARMT="off"
	tPPC="off"
	tSPARC="off"
	tia64="off"
	tDELTA="off"

	# clear Delta values if not selected
	if [ $FILTER != "--delta=" ] ; then
		DELTA=
		tDELTAVAL=1
	fi
	if [ $FILTER = "--x86" ] ; then
		tx86="on"
	elif [ $FILTER = "--arm" ] ; then
		tARM="on"
	elif [ $FILTER = "--armt" ] ; then
		tARMT="on"
	elif [ $FILTER = "--ppc" ] ; then
		tPPC="on"
	elif [ $FILTER = "--sparc" ] ; then
		tSPARC="on"
	elif [ $FILTER = "--ia64" ] ; then
		tia64="on"
	elif [ $FILTER = "--delta=" ] ; then
		tDELTA="on"
		# set Delta offset and remember it in tDELTAVAL
		dialog --clear \
			--title "Delta Value" \
			--inputbox "Enter Delta Filter Offset Value:" 0 41 "$tDELTAVAL" \
			2>/tmp/ldelta.dia
		check_error
		DELTA=$(</tmp/ldelta.dia)
		tDELTA="on"
		tDELTAVAL=$DELTA
	fi
}

get_level()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: Compression Level" \
		--no-tags \
		--item-help \
		--radiolist "Compression Level" \
		0 0 0 \
		--  \
		"L 1|--level=1" "Level 1" "$tLEVEL1" "Set Compression Level 1 for $METHOD" \
		"L 2|--level=2" "Level 2" "$tLEVEL2" "Set Compression Level 2 for $METHOD" \
		"L 3|--level=3" "Level 3" "$tLEVEL3" "Set Compression Level 3 for $METHOD" \
		"L 4|--level=4" "Level 4" "$tLEVEL4" "Set Compression Level 4 for $METHOD" \
		"L 5|--level=5" "Level 5" "$tLEVEL5" "Set Compression Level 5 for $METHOD" \
		"L 6|--level=6" "Level 6" "$tLEVEL6" "Set Compression Level 6 for $METHOD" \
		"L 7|--level=7" "Level 7 (default)" "$tLEVEL7" "Set Compression Level 7 for $METHOD" \
		"L 8|--level=8" "Level 8" "$tLEVEL8" "Set Compression Level 8 for $METHOD" \
		"L 9|--level=9" "Level 9" "$tLEVEL9" "Set Compression Level 9 for $METHOD" \
		2>/tmp/llevel.dia
	check_error
	return_sl_option "/tmp/llevel.dia"
	LEVEL=$RETURN_VAL
	tLEVEL1="off"
	tLEVEL2="off"
	tLEVEL3="off"
	tLEVEL4="off"
	tLEVEL5="off"
	tLEVEL6="off"
	tLEVEL7="off"
	tLEVEL8="off"
	tLEVEL9="off"

	if [ "$LEVEL" = "L 1" -o "$LEVEL" = "--level=1" ] ; then
		tLEVEL1="on"
	elif [ "$LEVEL" = "L 2" -o "$LEVEL" = "--level=2" ] ; then
		tLEVEL2="on"
	elif [ "$LEVEL" = "L 3" -o "$LEVEL" = "--level=3" ] ; then
		tLEVEL3="on"
	elif [ "$LEVEL" = "L 4" -o "$LEVEL" = "--level=4" ] ; then
		tLEVEL4="on"
	elif [ "$LEVEL" = "L 5" -o "$LEVEL" = "--level=5" ] ; then
		tLEVEL5="on"
	elif [ "$LEVEL" = "L 6" -o "$LEVEL" = "--level=6" ] ; then
		tLEVEL6="on"
	elif [ "$LEVEL" = "L 7" -o "$LEVEL" = "--level=7" ] ; then
		tLEVEL7="on"
	elif [ "$LEVEL" = "L 8" -o "$LEVEL" = "--level=8" ] ; then
		tLEVEL8="on"
	elif [ "$LEVEL" = "L 9" -o "$LEVEL" = "--level=9" ] ; then
		tLEVEL9="on"
	fi
}

get_rzip_level()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: RZIP Compression Level" \
		--no-tags \
		--item-help \
		--radiolist "RZIP Compression Level (Default = Compression Level)" \
		0 59 0 \
		--  \
		"R 1|--rzip-level=1" "Level 1" "$tRZIPLEVEL1" "Set RZIP Compression Level 1" \
		"R 2|--rzip-level=2" "Level 2" "$tRZIPLEVEL2" "Set RZIP Compression Level 2" \
		"R 3|--rzip-level=3" "Level 3" "$tRZIPLEVEL3" "Set RZIP Compression Level 3" \
		"R 4|--rzip-level=4" "Level 4" "$tRZIPLEVEL4" "Set RZIP Compression Level 4" \
		"R 5|--rzip-level=5" "Level 5" "$tRZIPLEVEL5" "Set RZIP Compression Level 5" \
		"R 6|--rzip-level=6" "Level 6" "$tRZIPLEVEL6" "Set RZIP Compression Level 6" \
		"R 7|--rzip-level=7" "Level 7" "$tRZIPLEVEL7" "Set RZIP Compression Level 7" \
		"R 8|--rzip-level=8" "Level 8" "$tRZIPLEVEL8" "Set RZIP Compression Level 8" \
		"R 9|--rzip-level=9" "Level 9" "$tRZIPLEVEL9" "Set RZIP Compression Level 9" \
		2>/tmp/lrlevel.dia
	check_error
	return_sl_option "/tmp/lrlevel.dia"
	RZIPLEVEL=$RETURN_VAL
	tRZIPLEVEL1="off"
	tRZIPLEVEL2="off"
	tRZIPLEVEL3="off"
	tRZIPLEVEL4="off"
	tRZIPLEVEL5="off"
	tRZIPLEVEL6="off"
	tRZIPLEVEL7="off"
	tRZIPLEVEL8="off"
	tRZIPLEVEL9="off"

	if [ "RZIPLEVEL" = "R 1" -o "RZIPLEVEL" = "--rzip-level=1" ] ; then
		tRZIPLEVEL1="on"
	elif [ "RZIPLEVEL" = "R 2" -o "RZIPLEVEL" = "--rzip-level=2" ] ; then
		tRZIPLEVEL2="on"
	elif [ "RZIPLEVEL" = "R 3" -o "RZIPLEVEL" = "--rzip-level=3" ] ; then
		tRZIPLEVEL3="on"
	elif [ "RZIPLEVEL" = "R 4" -o "RZIPLEVEL" = "--rzip-level=4" ] ; then
		tRZIPLEVEL4="on"
	elif [ "RZIPLEVEL" = "R 5" -o "RZIPLEVEL" = "--rzip-level=5" ] ; then
		tRZIPLEVEL5="on"
	elif [ "RZIPLEVEL" = "R 6" -o "RZIPLEVEL" = "--rzip-level=6" ] ; then
		tRZIPLEVEL6="on"
	elif [ "RZIPLEVEL" = "R 7" -o "RZIPLEVEL" = "--rzip-level=7" ] ; then
		tRZIPLEVEL7="on"
	elif [ "RZIPLEVEL" = "R 8" -o "RZIPLEVEL" = "--rzip-level=8" ] ; then
		tRZIPLEVEL8="on"
	elif [ "RZIPLEVEL" = "R 9" -o "RZIPLEVEL" = "--rzip-level=9" ] ; then
		tRZIPLEVEL9="on"
	fi
}

get_method()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: Compression Method" \
		--no-tags \
		--item-help \
		--radiolist "Compression Method" \
		0 0 0 \
		-- \
		"|--lzma" "lzma (default)" "$tLZMA" "Default LZMA Compression" \
		"b|--bzip" "bzip" "$tBZIP" "BZIP2 Compression" \
		"B|--bzip3" "bzip3" "$tBZIP3" "BZIP3 Compression" \
		"g|--gzip" "gzip" "$tGZIP" "GZIP Compression" \
		"l|--lzo" "lzo" "$tLZO" "LZO Compression" \
		"n|--rzip" "rzip" "$tRZIP" "Do NOT Compress. Just pre-process using RZIP (Fastest)." \
		"z|--zpaq" "zpaq" "$tZPAQ" "Use ZPAQ Compression (Slowest)." \
		2>/tmp/lmethod.dia
	check_error
	return_sl_option "/tmp/lmethod.dia"
	METHOD=$RETURN_VAL

	tLZMA="off"
	tBZIP="off"
	tBZIP3="off"
	tGZIP="off"
	tLZO="off"
	tRZIP="off"
	tZPAQ="off"

	if [ $METHOD = "--lzma" -o x$METHOD = "x" ] ; then
		tLZMA="on"
	elif [ $METHOD = "--bzip" -o $METHOD = "b" ] ; then
		tBZIP="on"
	elif [ $METHOD = "--bzip3" -o $METHOD = "B" ] ; then
		tBZIP3="on"
	elif [ $METHOD = "--gzip" -o $METHOD = "g" ] ; then
		tGZIP="on"
	elif [ $METHOD = "--lzo" -o $METHOD = "l" ] ; then
		tLZO="on"
	elif [ $METHOD = "--rzip" -o $METHOD = "n" ] ; then
		tRZIP="on"
	elif [ $METHOD = "--zpaq" -o $METHOD = "z" ] ; then
		tZPAQ="on"
	fi

}

get_output()
{
	# use temp variables for dialog and add command at end
	dialog --colors --backtitle "$BCOMMANDLINE" \
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

# make newline field separator local. No need to revert later.
	local IFS=$'\xA'
	local i=0
	for TMPVAR in $(</tmp/loutopts.dia)
	do
		TMPVAR="${TMPVAR/% /}" # remove trailing whitespace
		let i=$i+1
		case $i in
			1) tOUTDIR="$TMPVAR";;
			2) tOUTNAME="$TMPVAR";;
			3) tSUFFIX="$TMPVAR";;
		esac
	done

	if [ ! -z "$tOUTDIR" -a ! -z "$tOUTNAME" ] ; then
	       # ERROR
		dialog --title "ERROR!" --msgbox "Cannot specify both an\n\

Output Directory: $tOUTDIR \n\
and an \n\
Output Filename: $tOUTNAME \n\
\n\
Clearing both" 0 0
		tOUTDIR=
		tOUTNAME=
	fi

	OUTDIR=
	OUTNAME=
	if [ ! -z "$tOUTDIR" ] ; then
		return_sl_option_value "O $tOUTDIR" "--outdir=$tOUTDIR"
		OUTDIR="$RETURN_VAL"
	fi
	if [ ! -z "$tOUTNAME" ] ; then
		return_sl_option_value "o $tOUTNAME" "--outname=$tOUTNAME"
		OUTNAME="$RETURN_VAL"
	fi
	if [ ! -z "$tSUFFIX" ] ; then
		return_sl_option_value "S $tSUFFIX" "--suffix=$tSUFFIX"
		SUFFIX="$RETURN_VAL"
	fi
}

get_verbosity()
{
	dialog --colors --backtitle "$BCOMMANDLINE" \
		--title "$PROG: Verbosity" \
		--no-tags \
		--item-help \
		--radiolist "Verbosity" \
		0 0 0 \
		-- \
		"v|--verbose" "Verbose" "$tVERBOSE" "Show $LRZ settings and progress prior to compression/decompression" \
		"vv|--verbose --verbose" "Maximum Verbosity" "$tMAXVERBOSE" "Show compression/decompression/extra info on $LRZ execugtion in addition to -v option" \
		"P|--progress" "Show Progress" "$tPROGRESS" "Only show progress, no other verbose options on compression/decompression" \
		"q|--quiet" "Silent. Show no progress" "$tQUIET" "Be quiet and do not show progress on compression/decompression" \
		"Q|--very-quiet" "No Output. Suppress all  output" "$tVQUIET" "Be quiet and show no output on compression/decompression" \
		2>/tmp/lverbosity.dia
	check_error
	return_sl_option "/tmp/lverbosity.dia"
	VERBOSITY="$RETURN_VAL"

	tVERBOSE="off"
	tMAXVERBOSE="off"
	tPROGRESS="off"
	tQUIET="off"
	tVQUIET="off"

	if [ "$VERBOSITY" = "--verbose" -o $VERBOSITY = "v" ] ; then
		tVERBOSE="on"
	elif [ "$VERBOSITY" = "--verbose --verbose" -o $VERBOSITY = "vv" ] ; then
		tMAXVERBOSE="on"
	elif [ "$VERBOSITY" = "--progress" -o $VERBOSITY = "P" ] ; then
		tPROGRESS="on"
	elif [ "$VERBOSITY" = "--quiet" -o $VERBOSITY = "q" ] ; then
		tQUIET="on"
	elif [ "$VERBOSITY" = "--very-quiet" -o $VERBOSITY = "Q" ] ; then
		tVQUIET="on"
	fi

}


fillcommandline()
{
	COMMANDLINE="$LRZ"
	local firsttime=
	if [ "$SHORTLONG" = "LONG" ]; then
		[ ! -z $LMODE ]		&& COMMANDLINE="$COMMANDLINE $LMODE"
		[ ! -z $METHOD ]	&& COMMANDLINE="$COMMANDLINE $METHOD"
		[ ! -z $LEVEL ]		&& COMMANDLINE="$COMMANDLINE $LEVEL"
		[ ! -z $RZIPLEVEL ]	&& COMMANDLINE="$COMMANDLINE $RZIPLEVEL"
		[ ! -z "$VERBOSITY" ]	&& COMMANDLINE="$COMMANDLINE $VERBOSITY"
		[ ! -z $FORCE ]		&& COMMANDLINE="$COMMANDLINE $FORCE"
		[ ! -z $DELETE ]	&& COMMANDLINE="$COMMANDLINE $DELETE"
		[ ! -z $KEEP ]		&& COMMANDLINE="$COMMANDLINE $KEEP"
		[ ! -z "$OUTDIR" ]	&& COMMANDLINE="$COMMANDLINE $OUTDIR"
		[ ! -z "$OUTNAME" ]	&& COMMANDLINE="$COMMANDLINE $OUTNAME"
		[ ! -z "$SUFFIX" ]	&& COMMANDLINE="$COMMANDLINE $SUFFIX"
		[ ! -z $HASH ]		&& COMMANDLINE="$COMMANDLINE $HASH"
		[ ! -z $THREADS ]	&& COMMANDLINE="$COMMANDLINE $THREADS"
		[ ! -z $THRESHOLD ]	&& COMMANDLINE="$COMMANDLINE $THRESHOLD"
		[ ! -z $THRESHOLDPCT ]	&& COMMANDLINE="$COMMANDLINE $THRESHOLDPCT"
		[ ! -z $NICE ]		&& COMMANDLINE="$COMMANDLINE $NICE"
		[ ! -z $MAXRAM ]	&& COMMANDLINE="$COMMANDLINE $MAXRAM"
		[ ! -z $WINDOW ]	&& COMMANDLINE="$COMMANDLINE $WINDOW"
		[ ! -z $UNLIMITED ]	&& COMMANDLINE="$COMMANDLINE $UNLIMITED"
		[ ! -z $ENCRYPT ]	&& COMMANDLINE="$COMMANDLINE $ENCRYPT"
		[ ! -z $EMETHOD ]	&& COMMANDLINE="$COMMANDLINE $EMETHOD"
		[ ! -z $FILTER ]	&& COMMANDLINE="$COMMANDLINE $FILTER"
		[ ! -z $DELTA ]		&& COMMANDLINE="$COMMANDLINE$DELTA"
		[ ! -z "$COMMENT" ]	&& COMMANDLINE="$COMMANDLINE $COMMENT"
		[ ! -z $FILE ]		&& COMMANDLINE="$COMMANDLINE $FILE"
	else
		COMMANDLINE="$COMMANDLINE "
		let firsttime=0
		if [ ! -z $LMODE ] ; then
			COMMANDLINE="$COMMANDLINE-$LMODE"
			firsttime=1
		fi
		if [ ! -z $METHOD ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$METHOD"
			else
				COMMANDLINE="$COMMANDLINE-$METHOD"
				let firsttime=1
			fi
		fi
		if [ ! -z $VERBOSITY ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$VERBOSITY"
			else
				COMMANDLINE="$COMMANDLINE-$VERBOSITY"
				let firsttime=1
			fi
		fi
		if [ ! -z $FORCE ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$FORCE"
			else
				COMMANDLINE="$COMMANDLINE-$FORCE"
				let firsttime=1
			fi
		fi
		if [ ! -z $DELETE ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$DELETE"
			else
				COMMANDLINE="$COMMANDLINE-$DELETE"
				let firsttime=1
			fi
		fi
		if [ ! -z $KEEP ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$KEEP"
			else
				COMMANDLINE="$COMMANDLINE-$KEEP"
				let firsttime=1
			fi
		fi
		if [ ! -z $UNLIMITED ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$UNLIMITED"
			else
				COMMANDLINE="$COMMANDLINE-$UNLIMITED"
				let firsttime=1
			fi
		fi
		if [ ! -z "$THRESHOLD" ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$THRESHOLD"
			else
				COMMANDLINE="$COMMANDLINE-$THRESHOLD"
				let firsttime=1
			fi
		fi
		if [ ! -z $ENCRYPT ] ; then
			if [ $firsttime -eq 1 ] ; then
				COMMANDLINE="$COMMANDLINE$ENCRYPT"
			else
				COMMANDLINE="$COMMANDLINE-$ENCRYPT"
				let firsttime=1
			fi
		fi
		[ ! -z "$LEVEL" ]	&& COMMANDLINE="$COMMANDLINE -$LEVEL"
		[ ! -z "$RZIPLEVEL" ]	&& COMMANDLINE="$COMMANDLINE -$RZIPLEVEL"
		[ ! -z "$OUTDIR" ]	&& COMMANDLINE="$COMMANDLINE -$OUTDIR"
		[ ! -z "$OUTNAME" ]	&& COMMANDLINE="$COMMANDLINE -$OUTNAME"
		[ ! -z "$SUFFIX" ]	&& COMMANDLINE="$COMMANDLINE -$SUFFIX"
		[ ! -z "$THREADS" ]	&& COMMANDLINE="$COMMANDLINE -$THREADS"
		[ ! -z "$NICE" ]	&& COMMANDLINE="$COMMANDLINE -$NICE"
		[ ! -z "$MAXRAM" ]	&& COMMANDLINE="$COMMANDLINE -$MAXRAM"
		[ ! -z "$WINDOW" ]	&& COMMANDLINE="$COMMANDLINE -$WINDOW"
		[ ! -z "$THRESHOLDPCT" ] && COMMANDLINE="$COMMANDLINE -$THRESHOLDPCT"
		[ ! -z "$FILTER" ]	&& COMMANDLINE="$COMMANDLINE $FILTER"
		[ ! -z "$DELTA" ]	&& COMMANDLINE="$COMMANDLINE$DELTA"
		[ ! -z "$HASH" ]	&& COMMANDLINE="$COMMANDLINE -$HASH"
		[ ! -z "$EMETHOD" ]	&& COMMANDLINE="$COMMANDLINE -$EMETHOD"
		[ ! -z "$COMMENT" ]	&& COMMANDLINE="$COMMANDLINE -$COMMENT"
		[ ! -z "$FILE" ]	&& COMMANDLINE="$COMMANDLINE $FILE"
	fi

	# TAR Command
	# Only minimal useful commands used
	# tar -I|use-compress-program
	# compress -c,  decompress -x, test will equal list -t, info will equal -t
	# verbose will apply to tar, not lrzip
	# lrzip will show progress, otherwise no other verbose
	# output options emabled
	# force, keep, delete ignored
	# all advanced options ignored
	# encryption ignored
	# all tar options short except --use-compress-program/-I
	# tar file extension will always be and expect .tar.lrz

	TCOMMANDLINE=
	TARCOMMANDLINE="tar"
	let firsttime=0
	if [ "$SHORTLONG" = "LONG" ]; then
		TARCOMMANDLINE="$TARCOMMANDLINE --use-compress-program='$LRZ"
		[ ! -z $METHOD ]	&& TCOMMANDLINE="$TCOMMANDLINE $METHOD"
		[ ! -z $LEVEL ]		&& TCOMMANDLINE="$TCOMMANDLINE $LEVEL"
		[ ! -z $RZIPLEVEL ]	&& TCOMMANDLINE="$TCOMMANDLINE $RZIPLEVEL"
		[ ! -z $HASH ]		&& TCOMMANDLINE="$TCOMMANDLINE $HASH"
		[ ! -z $THRESHOLD ]	&& TCOMMANDLINE="$TCOMMANDLINE $THRESHOLD"
		[ ! -z $THRESHOLDPCT ]	&& TCOMMANDLINE="$TCOMMANDLINE $THRESHOLDPCT"
		[ ! -z $FILTER ]	&& TCOMMANDLINE="$TCOMMANDLINE $FILTER"
		[ ! -z $DELTA ]		&& TCOMMANDLINE="$TCOMMANDLINE$DELTA"
		[ ! -z "$COMMENT" ]	&& TCOMMANDLINE="$TCOMMANDLINE $COMMENT"
		[ ! -z "$VERBOSITY" ]	&& TCOMMANDLINE="$TCOMMANDLINE $VERBOSITY"
	else
		TARCOMMANDLINE="$TARCOMMANDLINE -I '$LRZ "
		if [ ! -z "$METHOD" ] ; then
			TCOMMANDLINE="$TCOMMANDLINE-$METHOD"
			let firsttime=1
		fi
		if [ ! -z "$VERBOSITY" ] ; then
			if [ $firsttime -eq 1 ] ; then
				TCOMMANDLINE="$TCOMMANDLINE$VERBOSITY"
			else
				TCOMMANDLINE="$TCOMMANDLINE-$VERBOSITY"
			fi
		fi
		if [ ! -z "$THRESHOLD" ] ; then
			if [ $firsttime -eq 1 ] ; then
				TCOMMANDLINE="$TCOMMANDLINE$THRESHOLD"
			else
				TCOMMANDLINE="$TCOMMANDLINE-$THRESHOLD"
			fi
		fi

		[ ! -z "$LEVEL" ]		&& TCOMMANDLINE="$TCOMMANDLINE -$LEVEL"
		[ ! -z "$RZIPLEVEL" ]		&& TCOMMANDLINE="$TCOMMANDLINE -$RZIPLEVEL"
		[ ! -z "$THRESHOLDPCT" ]	&& TCOMMANDLINE="$TCOMMANDLINE -$THRESHOLDPCT"
		[ ! -z "$FILTER" ]		&& TCOMMANDLINE="$TCOMMANDLINE $FILTER"
		[ ! -z "$DELTA" ]		&& TCOMMANDLINE="$TCOMMANDLINE$DELTA"
		[ ! -z "$COMMENT" ]		&& TCOMMANDLINE="$TCOMMANDLINE -$COMMENT"
	fi
	TARCOMMANDLINE="$TARCOMMANDLINE$TCOMMANDLINE'"

	TFILENAME="$FILE"
	if [ -z "$LMODE" ] ; then
		TARCOMMANDLINE="$TARCOMMANDLINE -c"
		# If FILE not set yet, skip, otherwise contruct output
		if [ ! -z "$FILE" ] ; then
			# if file does not have a .tar extension, add it
			[ ${FILE: -4} != ".tar" ] && TFILENAME="$FILE.tar"
			TFILENAME="$TFILENAME.lrz"
			if [ ! -z "$OUTDIR" ] ; then
				# strip lrzip command for OUTDIR
				if [ "$SHORTLONG" = "LONG" ] ; then
					ODIR="${OUTDIR#--outdir=}"
				else
					ODIR="${OUTDIR#O }"
				fi
				# add trailing slash if missing
				[ ${ODIR: -1} != "/" ] && ODIR="$ODIR/"
				# strip any leading directory for FILE
				TFILENAME="$ODIR$(basename $TFILENAME)"
			elif [ ! -z "$OUTNAME" ] ; then
				# strip lrzip command for OUTNAME
				if [ "$SHORTLONG" = "LONG" ] ; then
					TFILENAME="${OUTNAME#--outname=}"
				else
					TFILENAME="${OUTNAME#o }"
				fi
			fi
			# finish constructing compression command
			TFILENAME="$TFILENAME $FILE"
		fi
	elif [ $LMODE = "--decompress" -o $LMODE = "-d" ] ; then
		TARCOMMANDLINE="$TARCOMMANDLINE -x"
	elif [ $LMODE = "--test" -o $LMODE="-t" ] ; then
		TARCOMMANDLINE="$TARCOMMANDLINE -t"
	elif [ $LMODE = "--info" -o $LMODE="-i" ] ; then
		TARCOMMANDLINE="$TARCOMMANDLINE -t"
	fi

	if [ ! -z "$VERBOSITY" ] ; then
		if [ "$VERBOSITY" = "--verbose" -o "$VERBOSITY" = "v" ] ; then
			TARCOMMANDLINEV=v
		elif [ "$VERBOSITY" = "--verbose --verbose" -o "$VERBOSITY" = "vv" ] ; then
			TARCOMMANDLINEV=vv
		fi
		TARCOMMANDLINE="$TARCOMMANDLINE$TARCOMMANDLINEV"
	fi

	TARCOMMANDLINE="$TARCOMMANDLINE""f $TFILENAME"

	# set BCOMMANDLINE for BackTitle with inverted colors for tar
	BCOMMANDLINE="$COMMANDLINE | \Zr$TARCOMMANDLINE\ZR"
}

run_lrzip()
{
	dialog --title "Executing $LRZ" \
		--prgbox "$COMMANDLINE" "$COMMANDLINE" $height $width
}

run_tar_lrzip()
{
	dialog --title "Executing tar and $LRZ" \
		--prgbox "$TARCOMMANDLINE" "$TARCOMMANDLINE" $height $width
}

# Clear All VAriables
# At program start, all variables are cleared
# When user selects RESTART, all variables are cleared
clear_vars()
{
	# main program variables to construct an lrzip commandline
	LMODE=
	METHOD=
	LEVEL=
	RZIPLEVEL=
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
	THRESHOLDPCT=
	NICE=
	MAXRAM=
	WINDOW=
	UNLIITED=
	ENCRYPT=
	EMETHOD=
	COMMENT=
	RETURN_VAL=
	COMMANDLINE=
	TARCOMMANDLINE=
	BCOMMANDLINE=

# t Variables are temporary and hold values through the program unless restarted
# defaults are set as required
	tFILE=
	tLZMA="on"
	tBZIP="off"
	tBZIP3="off"
	tGZIP="off"
	tLZO="off"
	tRZIP="off"
	tZPAQ="off"
	tLEVEL1="off"
	tLEVEL2="off"
	tLEVEL3="off"
	tLEVEL4="off"
	tLEVEL5="off"
	tLEVEL6="off"
	tLEVEL7="on"
	tLEVEL8="off"
	tLEVEL9="off"
	tRZIPLEVEL1="off"
	tRZIPLEVEL2="off"
	tRZIPLEVEL3="off"
	tRZIPLEVEL4="off"
	tRZIPLEVEL5="off"
	tRZIPLEVEL6="off"
	tRZIPLEVEL7="off"
	tRZIPLEVEL8="off"
	tRZIPLEVEL9="off"
	tx86="off"
	tARM="off"
	tARMT="off"
	tPPC="off"
	tSPARC="off"
	tia64="off"
	tDELTA="off"
	tDELTAVAL=1
	tVERBOSE="off"
	tMAXVERBOSE="off"
	tPROGRESS="off"
	tQUIET="off"
	tVQUIET="off"
	tFORCE="off"
	tDELETE="off"
	tKEEP="off"
	tOUTDIR=
	tOUTNAME=
	tSUFFIX=
	tHASH=
	tTHREADS=
	tTHRESHOLD=
	tTHRESHOLDPCT=
	tNICE=
	tMAXRAM=
	tWINDOW=
	tUNLIMITED=
	tENCRYPT=
	tEMETHOD=
	tCOMMENT=
}

# Main program starts here


# set some globals
RETCODE=$DIALOG_EXTRA
SHORTLONG="LONG"

while [ $RETCODE -eq $DIALOG_EXTRA ]
do

# clear everything
clear_vars

if [ $SHORTLONG = "LONG" ] ; then
	LOCALSL="SHORT"
else
	LOCALSL="LONG"
fi

dialog	--backtitle "Current Directory is: $PWD" \
	--title "Welcome to $PROG - Version: $VERSION" \
	--no-tags \
	--extra-button --extra-label "Toggle $LOCALSL Commands" \
	--ok-label "Select $LRZ Mode" \
	--scrollbar \
	--hline "Press F1 for HELP" \
	--hfile "$LRZIPHELPFILE" \
	--exit-label "Close Help" \
	--menu "Copyright 2020 Peter Hyman\nA front-end for $LRZ\n\
Choose an $LRZ Action" \
	0 0 0 \
	"" "Compress a file" \
	"d|--decompress" "Decompress a file"  \
	"t|--test" "Test file integrity" \
	"i|--info" "Info - show file and stream block info" \
	"c|c" "Change working directory from $PWD" \
	2>/tmp/lmode.dia

check_error

#TOGGLE short or long command line options
if [ $RETCODE -eq $DIALOG_EXTRA ] ; then
	if [ $SHORTLONG = "LONG" ] ; then
		SHORTLONG="SHORT"
	else
		SHORTLONG="LONG"
	fi
	continue
fi

return_sl_option "/tmp/lmode.dia"
[ $? -eq -1 ] && RETURN_VAL=
LMODE=$RETURN_VAL

# Change Current Dir
if [ "$LMODE" = "c" ] ; then
	change_dir
	RETCODE=$DIALOG_EXTRA
	continue
elif [ -z $LMODE ]; then
	# Compress
	while (true)
	do
		fillcommandline
		dialog	--clear --colors --backtitle "$BCOMMANDLINE" \
			--title "$PROG: Compression Options" \
			--extra-button --extra-label "Restart" \
			--scrollbar \
			--hline "Press F1 for HELP" \
			--hfile "$LRZIPHELPFILE" \
			--exit-label "Close Help" \
			--menu "Compression Menu" \
			0 0 0 \
			"FILE"			"File or Directory to Compress" \
			"METHOD"		"Compression Method" \
			"LEVEL"			"Compression Level" \
			"RZIP LEVEL"		"RZIP Pre-Compression Level" \
			"FILTER"		"Pre-Compression Filter" \
			"VERBOSITY"		"Verbose Options" \
			"FILE HANDLING"		"Keep, Delete, Overwrite Files" \
			"OUTPUT"		"Output Options" \
			"ARCHIVE COMMENT"	"Add a plain text Comment for Archive" \
			"ADVANCED"		"Advanced Compression Options" \
			"RUN COMMAND"		"Run $LRZ Compression Program" \
			"RUN TAR COMMAND"	"Run $LRZ Compression under TAR Program" \
			"EXIT"			"Exit without running. Show Command Output" \
			2>/tmp/lrzip.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break

		MENU=$(</tmp/lrzip.dia)

		if [ "$MENU" = "FILE" ] ; then
			get_file
		elif [ "$MENU" = "METHOD" ] ; then
			get_method
		elif [ "$MENU" = "LEVEL" ] ; then
			get_level
		elif [ "$MENU" = "RZIP LEVEL" ] ; then
			get_rzip_level
		elif [ "$MENU" = "FILTER" ] ; then
			get_filter
		elif [ "$MENU" = "VERBOSITY" ] ; then
			get_verbosity
		elif [ "$MENU" = "FILE HANDLING" ] ; then
			get_file_handling
		elif [ "$MENU" = "OUTPUT" ] ; then
			get_output
		elif [ "$MENU" = "ARCHIVE COMMENT" ] ; then
			get_comment
		elif [ "$MENU" = "ADVANCED" ] ; then
			get_advanced
		elif [ "$MENU" = "RUN COMMAND" ] ; then
			run_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "RUN TAR COMMAND" ] ; then
			run_tar_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "EXIT" ] ; then
			break
		fi
	done
# done Compress
elif [ "$LMODE" = "--decompress" -o "$LMODE" = "d" ] ; then
	# Decompress
	while (true)
	do
		fillcommandline
		dialog	--clear --colors --backtitle "$BCOMMANDLINE" \
			--title "$PROG: Decompression Options" \
			--extra-button --extra-label "Restart" \
			--scrollbar \
			--hline "Press F1 for HELP" \
			--hfile "$LRZIPHELPFILE" \
			--exit-label "Close Help" \
			--menu "Decompression Menu" \
			0 0 0 \
			"FILE"		"File to Decompress" \
			"VERBOSITY"	"Verbose Options" \
			"FILE HANDLING" "Keep, Delete, Overwrite Files" \
			"OUTPUT"	"Output Options" \
			"RUN COMMAND"	"Run $LRZ Decompression Program" \
			"RUN TAR COMMAND" "Run $LRZ Decompression under TAR Program" \
			"EXIT"		"Done. Show Output" \
			2>/tmp/lrzip.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break
	MENU=$(</tmp/lrzip.dia)

		if [ "$MENU" = "FILE" ] ; then
			get_file
		elif [ "$MENU" = "VERBOSITY" ] ; then
			get_verbosity
		elif [ "$MENU" = "FILE HANDLING" ] ; then
			get_file_handling
		elif [ "$MENU" = "OUTPUT" ] ; then
			get_output
		elif [ "$MENU" = "RUN COMMAND" ] ; then
			run_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "RUN TAR COMMAND" ] ; then
			run_tar_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "EXIT" ] ; then
			break
		fi
	done
# done Decompress
elif [ "$LMODE" = "--test" -o "$LMODE" = "--info" -o "$LMODE" = "t" -o "$LMODE" = "i" ] ; then
	# Test or Info
	[ $LMODE = "--test" -o $LMODE = "t" ] && MODE="Test"
	[ $LMODE = "--info" -o $LMODE = "i" ] && MODE="Info"
	while (true)
	do
		fillcommandline
		dialog	--clear --colors --backtitle "$BCOMMANDLINE" \
			--title "$PROG: $MODE Options" \
			--extra-button --extra-label "Restart" \
			--scrollbar \
			--hline "Press F1 for HELP" \
			--hfile "$LRZIPHELPFILE" \
			--exit-label "Close Help" \
			--menu "$MODE Menu" \
			0 0 0 \
			"FILE"		"File to Decompress" \
			"VERBOSITY"	"Verbose Options" \
			"RUN COMMAND"	"Run $LRZ Compression Program" \
			"RUN TAR COMMAND" "Run $LRZ Compression under TAR Program" \
			"EXIT"		"Done. Show Output" \
			2>/tmp/lrzipfe.dia
		check_error
		[ $RETCODE -eq $DIALOG_EXTRA ] && break
	MENU=$(</tmp/lrzipfe.dia)

		if [ "$MENU" = "FILE" ] ; then
			get_file
		elif [ "$MENU" = "VERBOSITY" ] ; then
			get_verbosity
		elif [ "$MENU" = "RUN COMMAND" ] ; then
			run_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "RUN TAR COMMAND" ] ; then
			run_tar_lrzip
			# force restart
			RETCODE=$DIALOG_EXTRA
			break
		elif [ "$MENU" = "EXIT" ] ; then
			break
		fi
	done
# done Test or Info
fi

done # main outer loop

# Finish up by displaying the command
show_command "$LRZ command line options have been set/executed as follows" 0

#program ends from show_command()
