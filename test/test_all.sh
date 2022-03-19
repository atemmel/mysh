#!/bin/sh
to_test=$(ls *.mysh)

for file in $to_test
do 
	./$file > "/dev/null" 2>&1
	if [ $? -ne 0 ] ; then
		printf "\033[1;31mERROR:\033[0m Error interpreting $file\n"
	fi
done
