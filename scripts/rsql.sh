#!/bin/bash

[ -f "/etc/profile.d/ora_env.sh" ] && source /etc/profile.d/ora_env.sh
[ -f "/etc/sysconfig/oracle" ] && source /etc/sysconfig/oracle
[ -f "/etc/default/oracle" ] && source /etc/default/oracle
[ -f "/etc/rias/dba/rman.conf" ] && source /etc/rias/dba/rman.conf

if [ -z "$ORACLE_HOME" ]
then
 echo "ERR: ORACLE_HOME is not defined"
 exit 1
fi

if [ -z "$ORACLE_SID" ]
then
 echo "ERR: ORACLE_SID is not defined"
 exit 1
fi

$ORACLE_HOME/bin/sqlplus -S /nolog @./todo.sql
