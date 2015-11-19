#!/bin/sh
ping -q -c2 10.10.10.10 > /dev/null
ping -q -c2 10.10.10.30 > /dev/null
if [ $? -eq 0 ]
then
echo "ok"
else
mysql -uroot -psaphi -e "set global wsrep_provider_options='pc.bootstrap=1'"
echo "fix ok"
fi
