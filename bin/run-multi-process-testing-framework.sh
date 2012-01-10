# Copyright (C) 2011 Jacob Beard
# Released under GNU LGPL, read the file 'COPYING' for more information

dn=`dirname $0`
abspath=`cd $dn; pwd`

$abspath/bin/run-module.sh scxml/test/multi-process/server node -projectDir $abspath -local -numLocalProcesses 8 -interpreters spidermonkey rhino jsc v8 -verbose -logFile out.txt

#./bin/run-multi-process-testing-framework.sh -projectDir `pwd` -clientAddresses node-0{1..9} node-{10..19} node-{21..33} -interpreters v8 spidermonkey rhino -verbose -logFile out.txt -stopOnFail -clientModulePath `pwd`/src/main/coffeescript/scxml/test/multi-process/client.coffee

