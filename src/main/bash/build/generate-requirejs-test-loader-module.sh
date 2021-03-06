#!/bin/bash
#   Copyright 2011-2012 Jacob Beard, INFICON, and other SCION contributors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


target=$1

shift

tests="$*"

echo "define([" > $target

totalTests=$#
numTests=0

for testModule in $tests; do
	numTests=$(($numTests+1))

	truncatedTestModule=`echo $testModule | sed -e "s/.*target\///"`
	truncatedTestModuleWithoutExtension=${truncatedTestModule%.*}

	echo -ne "\t'$truncatedTestModuleWithoutExtension'" >> $target

	if [ $numTests -ne $totalTests ]; then
		echo , >> $target
	fi;
done;	

(
cat <<-EndOfFile
],function(){
	return Array.prototype.slice.call(arguments);
}); 
EndOfFile
) >> $target
