#!/bin/bash
systemctl status haproxy > /dev/null
if [[ "$?" != 0 ]];then
        echo "haproxy is down,close the keepalived"
        systemctl stop keepalived
fi
