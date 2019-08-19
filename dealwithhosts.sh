#!/bin/bash

SQLITEDB="/db/hostlistdb"
SQLITE="/usr/bin/sqlite3"
OUTPUT="/tmp/hostlist.txt"
[ -f "$OUTPUT" ] && cat /dev/null > $OUTPUT || touch $OUTPUT
SPOOLFILE="/tmp/spool.log"
[ -f "$SPOOLFILE" ] && cat /dev/null > $SPOOLFILE
JOBLOG="/tmp/joblog.log"

export SCRIPTDIR="/home/.../Parallel/scripts/"
export USERNAME="..."
export SSHPATH="/usr/bin/ssh"
export SCPPATH="/usr/bin/scp"
export SSHOPTION="-4 -q -o ServerAliveCountMax=5 -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export SCPOPTION="-4 -q -o Compression=yes -o ServerAliveCountMax=5 -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r"
export WORKDIR="~"

usage() {
cat << __EOFF__
Use: `basename $0` [options]...
        -h|--help       This help
        -m|--mean       (Required, with value) Shoud be one of: testing,www,...
        -a|--attr	(Req., w. val) Shoud be one of: node1,node2,ufqdn;
			-m|--mean & -a|--attr, if used, should be given both;
			And they are mutual exclusive with -l|--list
	-l|--list	(Req., w. val) List of fqdn; It's mutual exclusive with -m|--mean & -a|--attr
	-u|--user	(Optional w. val) OS-user, under who to do some at hosts;
			If not given, `basename $0` will try to connect and work at remote host(s) under ${USERNAME};
	-g|--group	(Opt., w. val) OS-group, supposed to be primary group of OS-user, whose name is setted by -u|--user
        -d|--dryrun     (Opt., without val) Actions at remote host(s) wouldn't be done;
			Just make list of host(s) ($OUTPUT) and show parallel-statement;
	-p|--dop	(Opt. w. val.) Degree Of Parallelism, should be a digit in range [0,32]; Default: 2;
	-w|--what	(Opt. w. val.) What to do, shell or sql script; shell|sql value aloowed;
			Default: shell;
__EOFF__
}

copytorh()
{
 #local v_localfile="$1"
 local v_host="$1"

 v_host=`echo -n "$v_host" | tr -d [:space:]`
 #echo $SCPPATH $SCPOPTION "$v_localfile" ${USERNAME}@${v_host}:${WORKDIR}
 $SCPPATH $SCPOPTION "$SCRIPTDIR" ${USERNAME}@${v_host}:${WORKDIR}
}
export -f copytorh


gethostlist() {
local v_mode="$1"
local v_tmp=""
local v_sql=""
local v_rc=""

case "$v_mode" in
 "list") v_sql="select name from hosts where name in (${v_list})"
         ;;
 "attribute") v_sql="select name from hosts where mean='${v_mean}' and attr='${v_attr}'"
            ;;
 *) echo "gethostlist was called with empty arg-list"
    return 1
   ;;
esac

#echo "$v_sql"

$SQLITE $SQLITEDB << __EOFF__ > $SPOOLFILE 2>&1
.mode column
select max(length(name))+2 as col from (${v_sql});
.exit
__EOFF__
v_rc="$?"
if [ "$v_rc" -ne "0" ]
then
 echo "Cannot ask $SQLITE $SQLITEDB with query: select max(length(name))+2 as col from (${v_tmp});"
 return $v_rc
fi

v_tmp=`cat $SPOOLFILE | tr -d [:space:]`
if [[ ! "$v_tmp" =~ [0-9]+ ]]
then
 echo "Cannot correctly determ max-width of hosts-fqdn"
 return 1
fi

v_sql=${v_sql}";"
#$SQLITE $SQLITEDB << __EOFF__ | awk -v sshu=$USERNAME -v ssh=$SSHPATH -v ssho="$SSHOPTION" '{printf "%s %s %s@%s\n", ssh, ssho, sshu, gensub(/ +/, "", "g", $0);}' > $OUTPUT
$SQLITE $SQLITEDB << __EOFF__ | awk '{printf "%s\n", gensub(/ +/, "", "g", $0);}' > $OUTPUT
.mode column
.width $v_tmp
$v_sql
.exit
__EOFF__

return 0

}

copy2remote() {

[ -f "$JOBLOG" ] && cat /dev/null > $JOBLOG
cat $OUTPUT | parallel --eta  --joblog $JOBLOG -d "\n" -j $v_dop copytorh {}
v_tmp=""
v_tmp=`cat $JOBLOG | awk '{ if ( NR > 1 ) {printf "%d\n", $7;}}' | sort -n -u | wc -l`
if [ -z "$v_tmp" -o "$v_tmp" -ne "1" ]
then
 echo "Can not scp file to remote hosts, see error in $JOBLOG"
 return 1
fi

v_tmp=`cat $JOBLOG | awk '{ if ( NR > 1 ) {printf "%d\n", $7;}}' | sort -n -u`
if [ "$v_tmp" -ne "0" ]
then
 echo "Can not scp file to remote hosts, see error in $JOBLOG"
 return 1
fi

echo "Files from ${SCRIPTDIR} distributed successfully"
return 0

}
## Main routine #########################################################################################
v_mean=""
v_attr=""
v_list=""
v_user=""
v_group=""
v_dryrun="0"
v_dop="2"
v_what="shell"

options=$(getopt -o dhm:a:l:u:g:p:w: -l help,mean:,attr:,list:,user:,group:,dop:,what: -- "$@")
eval set -- "$options"
while [ ! -z "$1" ]
do
 case "$1" in
  --) shift
    ;;
  -w|--what) shift
             v_what="$1"
             ;;
  -p|--dop) shift
            v_dop="$1"
            ;;
  -d|--dryrun) v_dryrun="1"
               ;;
  -u|--user) shift
             v_user="$1"
             ;;
  -g|--group) shift
              v_group="$1"
              ;;
  -m|--mean) shift
             v_mean="$1"
             ;;
  -h|--help) usage
             exit 0
             ;;
  -a|--attr) shift
             v_attr="$1"
             ;;
  -l|--list) shift
             v_list="$1"
	     ;;
 esac
 shift
done

v_mean=`echo -n ${v_mean} | tr [:upper:] [:lower:]`
v_attr=`echo -n ${v_attr} | tr [:upper:] [:lower:]`
v_list=`echo -n ${v_list} | tr [:upper:] [:lower:]`
v_what=`echo -n ${v_what} | tr [:upper:] [:lower:]`

if [[ ! "$v_what" =~ shell|sql ]]
then
 echo "-w|--what option is setted to incorrect value: ${v_what}"
 exit 1
fi

if [[ ! "$v_dop" =~ [0-9]+ ]]
then
 echo "-p|-dop option is setted to incorrect value: ${v_dop}"
 exit 1
fi

if [ "$v_dop" -lt "0" -o "$v_dop" -gt "32" ] 
then
  echo "-p|-dop option is setted to incorrect value: ${v_dop}"
  exit 1
fi

if [ ! -z "$v_group" -a -z "$v_user" ]
then
 echo "ERR: some unsense settings, OS-group is set (${v_group}), but OS-user is not'"
 exit 1
fi

if [ -z "$v_list" ]
then

 if [[ ! "$v_mean" =~ testing|www|... ]]
 then
  echo "value for -m|--mean option is incorrect;"
  exit 1
 fi

 if [[ ! "$v_attr" =~ node1|node2|ufqdn ]]
 then
  echo "value for -a|--attr option is incorrect;"
  exit 1
 fi
 
 gethostlist "attribute"
 if [ "$?" -ne "0" ]
 then
  echo "ERR: from gethostlist, attribute-mode"
  exit 1
 fi

else
# That is: if v_list isn't empty
 v_list=(${v_list//,/ })
v_tmp=""
for i in $(seq 0 $((${#v_list[@]} - 1)))
do
 if [ -z "$v_tmp" ]
 then
  v_tmp="'"${v_list[$i]}"'"
 else
  v_tmp=${v_tmp}",'"${v_list[$i]}"'"
 fi
done
v_list=${v_tmp}
v_tmp=""

 gethostlist "list"
 if [ "$?" -ne "0" ] 
 then 
  echo "ERR: from gethostlist, list-mode"
  exit 1
 fi

fi

 if [ "$v_dryrun" -eq "0" ]
 then
  copy2remote
  if [ "$?" -ne "0" ]
  then
   echo "ERR: from copy2remote"
   exit 1
  fi
 fi


 v_tmp=""
 [ ! -z "${v_user}" ] && v_tmp=" -u ${v_user}"
 [ ! -z "${v_group}" ] && v_tmp=${v_tmp}" -g ${v_group}"
 
 if [ "$v_dryrun" -eq "0" ]
 then
  [ -f "$JOBLOG" ] && cat /dev/null > $JOBLOG
  parallel --joblog $JOBLOG -j ${v_dop} --onall --slf <(cat "$OUTPUT" | awk -v sshu="$USERNAME" -v ssh="$SSHPATH" -v ssho="$SSHOPTION" '{printf "%s %s %s@%s\n", ssh, ssho, sshu, gensub(/ +/, "", "g", $0);}') bash -c ::: "cd; cd ./scripts; chmod u+x ./doshell.sh; ./doshell.sh -m ${v_what} ${v_tmp}"
  v_tmp=""
  v_tmp=`cat $JOBLOG | awk '{ if ( NR > 1 ) {printf "%d\n", $7;}}' | sort -n -u | wc -l`
  if [ -z "$v_tmp" -o "$v_tmp" -ne "1" ]
  then
   echo "ERR: some error(s) raised while work was being performed;"
  fi
  echo "JOBLOG is here: $JOBLOG"
 else
  echo "Dry-run required;"
  echo "New list of host was generated as: $OUTPUT"
  echo "Parallel statement is: "
  echo "parallel --joblog \$JOBLOG -j ${v_dop} --onall --slf <(cat \"\$OUTPUT\" | awk -v sshu=\"\$USERNAME\" -v ssh=\"\$SSHPATH\" -v ssho=\"\$SSHOPTION\" '{printf \"%s %s %s@%s\\n\", ssh, ssho, sshu, gensub(/ +/, \"\", \"g\", \$0);}') bash -c ::: \"cd; cd ./scripts; ./doshell.sh -m \${v_what} \${v_tmp}\""
  echo "Where:"
  echo "JOBLOG=$JOBLOG"
  echo "v_dop=$v_dop"
  echo "OUTPUT=$OUTPUT"
  echo "USERNAME=$USERNAME"
  echo "SSHPATH=$SSHPATH"
  echo "SSHOPTION=\"$SSHOPTION\""
  echo "v_tmp=\"$v_tmp\""
  echo "v_what=\"$v_what\""
 fi
