#!/bin/bash
set -e
# Description
#	- This script use for install tableau server
# Hardware recommendations
#	- 8 core, 2.0 GHz or higher processor
#	- 16 GB memory (Recommend 32 GB)
#	- 50 GB disk space available (Free 15+ GB -> /opt)
# Requirements
#	- Run by root user
#	- Software Tableau Server (Paste in same script path)
#	- Software PostgreSQL Driver (Paste in same script path)
# Note
#	- Download Tableau Server -> https://www.tableau.com/support/releases/server   tableau-server-<version>.x86_64.rpm
#	- Download PostgreSQL Driver -> https://www.tableau.com/support/drivers   tableau-postgresql-odbc-<version>.x86_64.rpm
#	- Original Source Page -> https://onlinehelp.tableau.com/current/server-linux/en-us/install_config_top.htm
#	- (Optional) Install font TH SarabunPSK at /usr/share/fonts && fc-cache -fv
#--------------Created by Ponlawat Rattanavayakorn--------------
#-----Main-----

tableau_file=auto							# Mandatory [auto | <Tableau_File>]
tableau_key=none							# Optional [<Product_Key> | none(trial license)]
tableau_reg_file=none						# Optional [<Register_File>(.json) | none(use create register file)]

tableau_site_user=admin
tableau_site_pass=admin
tableau_tsm_user=tableau
tableau_tsm_pass=tableau

#---Create Register File (Set if tableau_reg_file=none)---

reg_first_name="Homer"
reg_last_name="Simpson"
reg_phone="5558675309"
reg_email="homer@example.com"
reg_company="Example"
reg_industry="Energy"
reg_department="Engineering"
reg_title="Safety Inspection Engineer"
reg_state="OR"
reg_zip="97403"
reg_country="USA"
reg_city="Springfield"

#------------------30_Jan_2019-------------------
readonly current_path=$(cd "$(dirname "$0")" && pwd)
readonly server_ip=$(hostname -I | awk '{ print $1 }')

function _CheckSpec {
	server_memory=$(free -m | grep "^Mem:" | awk '{print $2}')
	server_cpu=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
	opt_directory=$(df -m /opt | tail -1 | awk '{print $4}')
	if [ ! ${server_memory} -gt 15000 ]; then
		echo "Error : Total memory is ${server_memory} MB. Request at least 16 GB"
		exit
	fi
	if [ ! ${server_cpu} -ge 8 ]; then
		echo "Error : Total CPU is ${server_cpu}. Request at least 8"
		exit
	fi
	if [ ! ${opt_directory} -gt 15360 ]; then
		echo "Error : Available space /opt is ${opt_directory} MB. Request at least 15 GB"
		exit
	fi
}

function _CheckUserRoot {
	if [[ $(whoami) != root ]]; then
		echo "Error : Please login as root"
		exit
	fi
}

function _CheckTableauFile {
	if [ ! -z ${tableau_file} ]; then
		if [[ ${tableau_file} == [Aa]uto ]]; then
			if ls tableau-server-*.x86_64.rpm 1> /dev/null 2>&1; then
				tableau_file=$(ls -pdL tableau-server-*.x86_64.rpm | grep -v /)
			else
				echo "Error : Tableau file auto error"
				exit
			fi
		fi
		if [ ! -e ${tableau_file} ]; then
			echo "Error : ${tableau_file} not found"
			exit
		fi
	else
		echo "Error : Tableau file is null"
		exit
	fi
}

function _CreateUserTableau {
	if [[ $(id -u ${tableau_tsm_user} > /dev/null 2>&1; echo $?) == 1 ]]; then
		useradd ${tableau_tsm_user}
		echo "Success : Create user ${tableau_tsm_user} complete"
	fi
	echo ${tableau_tsm_pass} | passwd --stdin ${tableau_tsm_user} > /dev/null
}

function _AllowPortFirewall {
	if [ $(ps -ef | grep -v grep | grep firewalld | wc -l) -gt 0 ]; then
		firewall-cmd --quiet --permanent --add-port=80/tcp --add-port=8850/tcp
		firewall-cmd --quiet --reload
	fi
}

function _ConfigTableauKey {
	if [ -z ${tableau_key} ] || [[ ${tableau_key} == [Nn]one ]]; then
		activate_key="-t"
	else
		activate_key="-k ${tableau_key}"
	fi
}

function _ConfigRegJson {
	if [ -z ${tableau_reg_file} ] || [[ ${tableau_reg_file} == [Nn]one ]]; then
		echo "{
  \"zip\" : \"${reg_zip}\",
  \"country\" : \"${reg_country}\",
  \"city\" : \"${reg_city}\",
  \"last_name\" : \"${reg_last_name}\",
  \"industry\" : \"${reg_industry}\",
  \"eula\" : \"yes\",
  \"title\" : \"${reg_title}\",
  \"phone\" : \"${reg_phone}\",
  \"company\" : \"${reg_company}\",
  \"state\" : \"${reg_state}\",
  \"department\" : \"${reg_department}\",
  \"first_name\" : \"${reg_first_name}\",
  \"email\" : \"${reg_email}\"
}" > tableau-reg-file.json
		tableau_reg_file=tableau-reg-file.json
	else
		if [ ! -e ${tableau_reg_file} ] || [[ ${tableau_reg_file} != *.json ]]; then
			echo "Error : ${tableau_reg_file} is missing"
			exit
		fi
	fi
}

function _CreateIdentityStoreJson {
	echo "{
 \"configEntities\":{
  \"identityStore\": {
   \"_type\": \"identityStoreType\",
   \"type\": \"local\"
   }
  }
}" > local_identitystore.json
}

function _ConfigMailJson {
		echo "{
\"configKeys\": {
        \"svcmonitor.notification.smtp.server\": \"smtp.live.com\",
        \"svcmonitor.notification.smtp.send_account\": \"test@hotmail.com\",
        \"svcmonitor.notification.smtp.port\": 25,
        \"svcmonitor.notification.smtp.password\": \"password\",
        \"svcmonitor.notification.smtp.ssl_enabled\": true,
        \"svcmonitor.notification.smtp.from_address\": \"test@hotmail.com\",
        \"svcmonitor.notification.smtp.target_addresses\": \"test@hotmail.com\",
        \"svcmonitor.notification.smtp.canonical_url\": \"http://$(hostname -I)\"
              }
}" > tableau-mail-file.json
}

function _InstallPostgresDriver {
	if [ $(rpm -qa | grep "^tableau-postgresql-odbc" | wc -l) -eq 0 ]; then
		if [ -e tableau-postgresql-odbc-*.x86_64.rpm ]; then
			yum install -y tableau-postgresql-odbc-*.x86_64.rpm
		else
			echo "Warning : PostgreSQL driver not install"
		fi
	fi
}

function _CreateServiceScript {
	echo "#!/bin/bash
# chkconfig: 2345 95 65
# ---Created by Ponlawat Rattanavayakorn---
tsm_username=${tableau_tsm_user}
tsm_password=${tableau_tsm_pass}
start() {
        su - \${tsm_username} -c \"tsm start -u \${tsm_username} -p \${tsm_password}\"
}
stop() {
        su - \${tsm_username} -c \"tsm stop -u \${tsm_username} -p \${tsm_password}\"
}
restart() {
        su - \${tsm_username} -c \"tsm stop -u \${tsm_username} -p \${tsm_password}\"
        su - \${tsm_username} -c \"tsm start -u \${tsm_username} -p \${tsm_password}\"
}
status() {
        su - \${tsm_username} -c \"tsm status -u \${tsm_username} -p \${tsm_password}\"
}

case \"\$1\" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart)
        restart
        ;;
  status)
        status
        ;;
  *)
        echo \$\"Usage: \$0 {start|stop|status|restart}\"
        exit 1
esac
exit 0" > /etc/init.d/tableau
	chmod 755 /etc/init.d/tableau
	chkconfig --add tableau
}

function _CreateBackupScript {
	echo "#!/bin/bash
#---Created by Ponlawat Rattanavayakorn---
tsm maintenance cleanup -u ${tableau_tsm_user} -p ${tableau_tsm_pass}
tsm maintenance backup -f tableau_backup.tsbak -d -u ${tableau_tsm_user} -p ${tableau_tsm_pass}
if [ \$(ls /var/opt/tableau/tableau_server/data/tabsvc/files/backups|wc -l) -gt 7 ]; then
	find /var/opt/tableau/tableau_server/data/tabsvc/files/backups -type f -mtime +7 -delete
fi" > /home/${tableau_tsm_user}/tableau_backup.sh
	chown ${tableau_tsm_user}:${tableau_tsm_user} /home/${tableau_tsm_user}/tableau_backup.sh
	chmod 700 /home/${tableau_tsm_user}/tableau_backup.sh
	echo "10 1 * * * /home/${tableau_tsm_user}/tableau_backup.sh" | tee -a /var/spool/cron/${tableau_tsm_user} > /dev/null
}

function _InstallTableau {
# Install Tableau Server
	if [ $(rpm -qa | grep "^tableau-server" | wc -l) -eq 0 ]; then
		yum install -y ${tableau_file}
	else
		echo "Warning : Tableau Server was already installed"
	fi
# Initialize TSM
	_CreateUserTableau
	_AllowPortFirewall
	if [ ! -d /var/opt/tableau ]; then
		/opt/tableau/tableau_server/packages/scripts.*/initialize-tsm --accepteula -a ${tableau_tsm_user}
	else
		echo "Error : /var/opt/tableau was already created"
		exit
	fi
	su - root -c "tsm login -u ${tableau_tsm_user} <<< ${tableau_tsm_pass}"
	_ConfigTableauKey
	su - root -c "tsm licenses activate ${activate_key}"
	_ConfigRegJson
	su - root -c "tsm register --file ${current_path}/${tableau_reg_file}"
	_CreateIdentityStoreJson
	#tsm user-identity-store verify-user-mappings -v tableau
	su - root -c "tsm settings import -f ${current_path}/local_identitystore.json"
	_ConfigMailJson
	su - root -c "tsm settings import -f ${current_path}/tableau-mail-file.json
	tsm pending-changes apply
	tsm initialize --start-server --request-timeout 1800
	tabcmd initialuser --server localhost:80 --username ${tableau_site_user} --password ${tableau_site_pass}"
	_InstallPostgresDriver
	_CreateServiceScript
	_CreateBackupScript
}

_CheckSpec
_CheckUserRoot
_CheckTableauFile
_InstallTableau

function _Summary {
	echo "~~~~~~~~~~~~~~~~~~~~Tableau Server~~~~~~~~~~~~~~~~~~~~
Tableau Version       : $(su - root -c "tsm version" | grep "^Tableau Server version" | awk '{ print substr($4, 1, length($4)-1) }')
Tableau Install Path  : /var/opt/tableau/tableau_server/
Tableau Services      : /var/opt/tableau/tableau_server/data/tabsvc
Tableau Backup Path   : /var/opt/tableau/tableau_server/data/tabsvc/files/backups/
Tableau Logs          : /var/opt/tableau/tableau_server/data/tabsvc/logs/tabadmincontroller/tabadmincontroller_*.log
Tableau Port          : 80, 8850
Tableau Site Page     : http://${server_ip}
Tableau Site Username : ${tableau_site_user}
Tableau Site Password : ${tableau_site_pass}
Tableau TSM Page      : https://${server_ip}:8850
Tableau TSM Username  : ${tableau_tsm_user}
Tableau TSM Password  : ${tableau_tsm_pass}
Tableau Show Command  : tsm -h
Tableau Login TSM     : tsm login -u ${tableau_tsm_user}
Tableau Start Server  : tsm start
Tableau Stop Server   : tsm stop

~~~~~~~~~~~~~~~~~~~~Tableau OS User~~~~~~~~~~~~~~~~~~~
OS Username           : ${tableau_tsm_user}
OS Password           : ${tableau_tsm_pass}
Home Directory        : /home/${tableau_tsm_user}

$(date | awk '{ print $3 }')-$(date | awk '{ print $2 }')-$(date | awk '{ print $6 }') $(date +%r)
~~~~~~~~~~~~~~~~~Created by Ponlawat Rattanavayakorn~~~~~~~~~~~~~~~~~" > Tableau_Server_Detail.txt
}

_Summary

echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Notice~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Note : Schedule backup every day at 01:10:00
Note : Created file Tableau_Server_Detail.txt\n"
cat Tableau_Server_Detail.txt
echo -e "\nBye (^-^)/~~~~~~~~~~~~~~~~~~~~"
exec bash
exit 0