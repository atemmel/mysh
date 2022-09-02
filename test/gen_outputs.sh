#!/bin/sh

to_test=$(ls *.mysh)

for file in $to_test
do
	output_file="output/$file"
	if [ -e "$output_file" ] ; then
		continue
	fi

	./$file > "output/$file"
done
