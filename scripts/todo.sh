#!/bin/bash

[ -f "/etc/profile.d/ora_env.sh" ] && source /etc/profile.d/ora_env.sh
[ -f "/etc/sysconfig/oracle" ] && source /etc/sysconfig/oracle
[ -f "/etc/default/oracle" ] && source /etc/default/oracle
[ -f "/etc/rias/dba/rman.conf" ] && source /etc/rias/dba/rman.conf

#echo "`whoami` `pwd` `hostname -f`"
#echo "info all" | $HOME/ggsci
#echo "`hostname -f` `df -B 1G /mnt/rman_nfs/ | grep "rman_nfs" | tr -d [%]`"

if [ "$DATABASE_ROLE" == "PRIMARY" ]
then
echo -e "set head off\nselect SEQUENCE#||'' as seq from v\$log where STATUS='CURRENT';" | $ORACLE_HOME/bin/sqlplus -S "/ as sysdba" | egrep -o "[0-9]+" > /tmp/temp.txt
logseq=`cat /tmp/temp.txt`
echo "${DATABASE_ROLE} ${logseq}"
fi

if [ "$DATABASE_ROLE" == "PHYSICAL STANDBY" ]
then
echo "select max(SEQUENCE#) from v\$archived_log where FIRST_CHANGE#<(select current_scn from v\$database) and RESETLOGS_CHANGE#=(select RESETLOGS_CHANGE# from v\$database);" | $ORACLE_HOME/bin/sqlplus -S "/ as sysdba" | egrep -o "[0-9]+" > /tmp/temp.txt
logseq=`cat /tmp/temp.txt`
echo "${DATABASE_ROLE} ${logseq}"
fi


