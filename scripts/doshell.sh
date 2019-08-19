

#[ -f "/etc/profile.d/ora_env.sh" ] && source /etc/profile.d/ora_env.sh
#[ -f "/etc/sysconfig/oracle" ] && source /etc/sysconfig/oracle
#[ -f "/etc/default/oracle" ] && source /etc/default/oracle
#[ -f "/etc/rias/dba/rman.conf" ] && source /etc/rias/dba/rman.conf

usage() {
cat << __EOFF__
`hostname -f`
Use: `basename $0` [options]...
	-h|--help	This help
	-u|--user	Name to say hello to
	-g|--group	Name of user group
        -m|--mode	Shell or SQL script to do; Have to be shell|sql
__EOFF__
}

v_script2exec="todo.sh"
v_sqlscript="todo.sql"
v_sqlexec="rsql.sh"
v_logon_user=`id -un`
v_user="$v_logon_user"
v_group=""
v_host=`hostname -f`
v_mode="shell"

options=$(getopt -o hu:g:m: -l help,user:,group:,mode: -- "$@")
eval set -- "$options"
while [ ! -z "$1" ]
do
 case "$1" in
  --) shift
    ;;
  -m|--mode) shift
             v_mode="$1"
             ;;
  -u|--user) shift
	     v_user="$1"
             ;;
  -h|--help) usage
	     exit 0
	     ;;
  -g|--group) shift
	      v_group="$1"
	      ;;
 esac
 shift
done

if [[ ! "$v_mode" =~ shell|sql ]]
then
 echo "ERR: -m|--mode have to be shell|sql"
 exit 1
fi

v_rc="0"
if [ ! -z "$v_group" ]
then
 sudo egrep -q "^${v_group}:" /etc/group
 v_rc=$?
fi

if [ "$v_rc" -ne "0" ]
then
 echo "ERR: group ${v_group} does not exit at ${v_host}"
 exit 1
fi

v_rc="0"
if [ "$v_user" != "$v_logon_user" ]
then
 sudo id -u ${v_user} 1>/dev/null 2>&1
 v_rc=$?
fi
if [ "$v_rc" -ne "0" ]
then
 echo "ERR: user ${v_user} does not exit at ${v_host}"
 exit 1
fi

if [ "$v_user" != "$v_logon_user" -a -z "$v_group" ]
then
 v_group=`sudo id -gn ${v_user}`
fi


if [ ! -f "$v_script2exec" -a "$v_mode" == "shell" ]
then
 echo "ERR: script ${v_script2exec} not found at ${v_host} in `pwd`"
 exit 1
else
 sudo chmod u+x "$v_script2exec"
fi

if [ ! -f "$v_sqlexec" -a "$v_mode" == "sql" ]
then
 echo "ERR: script ${v_sqlexec} not found at ${v_host} in `pwd`"
 exit 1
else
 sudo chmod u+x "$v_sqlexec"
fi


if [ "$v_mode" == "sql" ]
then
 if [ ! -f "$v_sqlscript" ] 
 then
  echo "ERR: sql-script $v_sqlscript not found at ${v_host} in `pwd`!"
  exit 1
 fi
fi

#echo "$v_host hello ${v_user}:${v_group}"
if [ "$v_user" != "$v_logon_user" ]
then
  if [ "$v_mode" == "sql" ] 
  then
   sudo chown ${v_user}:${v_group} ./${v_sqlscript}
   sudo chown ${v_user}:${v_group} ./${v_sqlexec}
   sudo -u ${v_user} ./${v_sqlexec}
  else
   sudo chown ${v_user}:${v_group} ./${v_script2exec}
   sudo -u ${v_user} ./${v_script2exec} 
  fi
else
 if  [ "$v_mode" == "sql" ]
 then
  ./${v_sqlexec} 
 else
  ./${v_script2exec}
 fi
fi

[ -f "${v_sqlscript}" ] && sudo rm -f ${v_sqlscript}
[ -f "${v_sqlexec}" ] && sudo rm -f ${v_sqlexec}
[ -f "${v_script2exec}" ] && sudo rm -f ${v_script2exec}
