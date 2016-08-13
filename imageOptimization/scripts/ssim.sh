#!/bin/bash
#
# Developed by Fred Weinhaus 1/14/2016 .......... revised 1/14/2016
#
# ------------------------------------------------------------------------------
#
# Licensing:
#
# Copyright © Fred Weinhaus
#
# My scripts are available free of charge for non-commercial use, ONLY.
#
# For use of my scripts in commercial (for-profit) environments or
# non-free applications, please contact me (Fred Weinhaus) for
# licensing arrangements. My email address is fmw at alink dot net.
#
# If you: 1) redistribute, 2) incorporate any of these scripts into other
# free applications or 3) reprogram them in another scripting language,
# then you must contact me for permission, especially if the result might
# be used in a commercial or for-profit environment.
#
# My scripts are also subject, in a subordinate manner, to the ImageMagick
# license, which can be found at: http://www.imagemagick.org/script/license.php
#
# ------------------------------------------------------------------------------
#
####
#
# USAGE: ssim [-f format] [-p precision] infile1 infile2 [outfile]
# USAGE: ssim [-h or -help]
#
# OPTIONS:
#
# -f     format        FORMAT is the output image format, if the outfile is
#                      specified; choices are: ssim or dssim; default=ssim
# -p     precision     PRECISION is the number of decimal figures in the
#                      metric to show; default=3
#
###
#
# NAME: SSIM
#
# PURPOSE: To compute the structural similarity metric between two equal sized
# images.
#
# DESCRIPTION: SSIM computes the structural similarity metric between two
# equal sized images and its complement structural dissimilarity metric
# (DSSIM). The DSSIM=(1-SSIM). An optional output image may be specified which
# can show the SSIM or DSSIM image. The latter is just the -negate of the
# former. The SSIM process first converts the images to Luma space and then
# computes the ssim metric within 11x11 local regions at every pixel with
# Gaussian weighting. Then it computes the average ssim value across the
# resulting ssim image and reports that value.
#
# Arguments:
#
# -f format ... FORMAT is the output image format, if the outfile is specified.
# The choices are: ssim (s) or dssim (d). The default=ssim
#
# -p precision ... PRECISION is the number of decimal figures in the metric
# to show. The default=3
#
# REFERENCES:
# http://en.m.wikipedia.org/wiki/SSIM
# https://en.wikipedia.org/wiki/Covariance
# http://www.cns.nyu.edu/pub/eero/wang03-reprint.pdf
# http://www.cns.nyu.edu/~lcv/ssim/
#
# NOTE: This script will process only the first frame/page of a multiframe or
# multipage image.
#
# NOTE: Without HDRI enabled, there may be some rounding errors so that the
# SSIM metric on the image against itself may not be an exact 1, especially
# if precision is higher than the default.
#
# CAVEAT: No guarantee that this script will work on all platforms,
# nor that trapping of inconsistent parameters is complete and
# foolproof. Use At Your Own Risk.
#
######
#

# set default values
format="ssim"
precision=3
radius=5
sigma=1.5
k1=0.01
k2=0.03
L=1			# fx is in range 0 to 1; so 2^1-1 = 1


# set directory for temporary files
tmpdir="/tmp"


# set up functions to report Usage and Usage with Description
PROGNAME=`type $0 | awk '{print $3}'`  # search for executable on path
PROGDIR=`dirname $PROGNAME`            # extract directory of program
PROGNAME=`basename $PROGNAME`          # base name of program
usage1()
	{
	echo >&2 ""
	echo >&2 "$PROGNAME:" "$@"
	sed >&2 -e '1,/^####/d;  /^###/g;  /^#/!q;  s/^#//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
	}
usage2()
	{
	echo >&2 ""
	echo >&2 "$PROGNAME:" "$@"
	sed >&2 -e '1,/^####/d;  /^######/g;  /^#/!q;  s/^#*//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
	}


# function to report error messages
errMsg()
	{
	echo ""
	echo $1
	echo ""
	usage1
	exit 1
	}


# function to test for minus at start of value of second part of option 1 or 2
checkMinus()
	{
	test=`echo "$1" | grep -c '^-.*$'`   # returns 1 if match; 0 otherwise
    [ $test -eq 1 ] && errMsg "$errorMsg"
	}

# test for correct number of arguments and get values
if [ $# -eq 0 ]
	then
	# help information
   echo ""
   usage2
   exit 0
elif [ $# -gt 7 ]
	then
	errMsg "--- TOO MANY ARGUMENTS WERE PROVIDED ---"
else
	while [ $# -gt 0 ]
		do
			# get parameter values
			case "$1" in
	  -h|-help)    # help information
				   echo ""
				   usage2
				   exit 0
				   ;;
			-f)    # get format
				   shift  # to get the next parameter
				   # test if parameter starts with minus sign
				   errorMsg="--- INVALID FORMAT SPECIFICATION ---"
				   checkMinus "$1"
				   format=`echo "$1" | tr "[:upper:]" "[:lower:]"`
				   case "$format" in
						ssim|s) format="ssim";;
						dssim|d) format="dssim";;
						*) errMsg "--- FORMAT=$format IS NOT A VALID CHOICE ---" ;;
				   esac
				   ;;
			-p)    # get precision
				   shift  # to get the next parameter
				   # test if parameter starts with minus sign
				   errorMsg="--- INVALID PRECISION SPECIFICATION ---"
				   checkMinus "$1"
				   precision=`expr "$1" : '\([0-9]*\)'`
				   [ "$precision" = "" ] && errMsg "--- PRECISION=$precision MUST BE A NON-NEGATIVE INTEGER ---"
				   ;;
			 -)    # STDIN and end of arguments
				   break
				   ;;
			-*)    # any other - argument
				   errMsg "--- UNKNOWN OPTION ---"
				   ;;
			 *)    # end of arguments
				   break
				   ;;
			esac
			shift   # next option
	done
	#
	# get infile
	infile1="$1"
	infile2="$2"
	outfile="$3"
fi

# test that infile1 provided
[ "$infile1" = "" ] && errMsg "--- NO INPUT FILE 1 SPECIFIED ---"

# test that infile2 provided
[ "$infile2" = "" ] && errMsg "--- NO INPUT FILE 1 SPECIFIED ---"


dir="$tmpdir/SSIM.$$"

mkdir "$dir" || errMsg "--- FAILED TO CREATE TEMPORARY FILE DIRECTORY ---"
trap "rm -rf $dir; exit 0" 0
trap "rm -rf $dir; exit 1" 1 2 3 15

if [ "$outfile" != "" -a "$format" = "ssim" ]; then
	out="+write $outfile"
elif [ "$outfile" != "" -a "$format" = "dssim" ]; then
	out="-negate +write $outfile -negate"
else
	out=""
fi

# read the input image into the temporary cached image and test if valid
convert -quiet -regard-warnings "$infile1[0]" -alpha off -grayscale Rec709luma +repage $dir/tmpI1.mpc ||
	echo  "--- FILE $infile1 DOES NOT EXIST OR IS NOT AN ORDINARY FILE, NOT READABLE OR HAS ZERO SIZE  ---"

convert -quiet -regard-warnings "$infile2[0]" -alpha off -grayscale Rec709luma +repage $dir/tmpI2.mpc ||
	echo  "--- FILE $infile2 DOES NOT EXIST OR IS NOT AN ORDINARY FILE, NOT READABLE OR HAS ZERO SIZE  ---"


# validate that the two images are the same size
size1=`convert -ping $dir/tmpI1.mpc -format "%wx$h" info:`
size2=`convert -ping $dir/tmpI2.mpc -format "%wx$h" info:`
w1=`echo "$size1" | cut -dx -f1`
h1=`echo "$size1" | cut -dx -f2`
w2=`echo "$size2" | cut -dx -f1`
h2=`echo "$size2" | cut -dx -f2`
[ $w1 != $w2 ] && errMsg="--- INPUT IMAGE WIDTHS ARE NOT THE SAME SIZE ---"
[ $h1 != $h2 ] && errMsg="--- INPUT IMAGES HEIGHTS ARE NOT THE SAME SIZE ---"


# compute c from k
c1=`convert xc: -format "%[fx:($L*$k1)*($L*$k1)]" info:`
c2=`convert xc: -format "%[fx:($L*$k2)*($L*$k2)]" info:`


# get mean images
convert $dir/tmpI1.mpc -blur ${radius}x${sigma} $dir/tmpM1.mpc

convert $dir/tmpI2.mpc -blur ${radius}x${sigma} $dir/tmpM2.mpc

# get var images
convert \( $dir/tmpI1.mpc $dir/tmpI1.mpc -compose multiply -composite \) \
\( $dir/tmpM1.mpc $dir/tmpM1.mpc -compose multiply -composite \) \
+swap -compose minus -composite -blur ${radius}x${sigma} $dir/tmpV1.mpc

convert \( $dir/tmpI2.mpc $dir/tmpI2.mpc -compose multiply -composite \) \
\( $dir/tmpM2.mpc $dir/tmpM2.mpc -compose multiply -composite \) \
+swap -compose minus -composite -blur ${radius}x${sigma} $dir/tmpV2.mpc

# get cov image
convert \( $dir/tmpI1.mpc $dir/tmpI2.mpc -compose multiply -composite \) \
\( $dir/tmpM1.mpc $dir/tmpM2.mpc -compose multiply -composite \) \
+swap -compose minus -composite -blur ${radius}x${sigma} $dir/tmpC12.mpc

# get ssim and dsim
ssim=`convert $dir/tmpM1.mpc $dir/tmpM2.mpc $dir/tmpV1.mpc $dir/tmpV2.mpc $dir/tmpC12.mpc \
	\( -clone 0,1 -define compose:args="2,0,0,$c1" -compose mathematics -composite \) \
	\( -clone 4 -function polynomial "2,$c2" \) \
	\( -clone 0 -function polynomial "1,0,0" \) \
	\( -clone 1 -function polynomial "1,0,$c1" \) \
	\( -clone 7,8 -compose plus -composite \) \
	-delete 7,8 \
	\( -clone 2,3 -define compose:args="0,1,1,$c2" -compose mathematics -composite \) \
	-delete 0-4 \
	\( -clone 0,1 -compose multiply -composite \) \
	\( -clone 2,3 -compose multiply -composite \) \
	-delete 0-3 \
	+swap -compose divide -composite $out \
	-precision $precision -format "%[fx:mean]" info:`
dssim=`convert xc: -precision $precision -format "%[fx:(1-$ssim)]" info:`

echo "ssim=$ssim dssim=$dssim"

exit 0
