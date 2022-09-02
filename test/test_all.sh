#!/bin/sh

END="\033[0m"
ERRBEG="\033[1;31m"
WARNBEG="\033[1;33m"
ERR="$ERRBEG ERROR: $END"
WARN="$WARNBEG WARNING: $END"

to_test=$(ls *.mysh)

for file in $to_test
do 
	output=$(./$file 2> "/dev/null")
	if [ $? -ne 0 ] ; then
		printf "$ERR Error interpreting $file\n"
	fi
	output_file="output/$file"
	expected=$(grep -h "" "$output_file" 2> "/dev/null")
	if [ $? -ne 0 ] ; then 
		printf "$WARN No matching output file found for $file\n"
	elif [ "$output" != "$expected" ] ; then
		printf "$ERR Output from $file differs from $output_file\n"
	fi
done
