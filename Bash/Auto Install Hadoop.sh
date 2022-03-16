#!/bin/bash
set -e
# Description
#	- This script use for install hadoop
# Requirements
#	- Run by root user
#	- Software JAVA (Paste in same script path or use full path of JAVA dir/link)
#	- Software Hadoop (Paste in same script path)
# Note
#	- Download JAVA -> jdk-<version>-linux-x64.tar.gz
#	- Download Hadoop -> hadoop-<version>/hadoop-<version>.tar.gz
#--------------Created by Ponlawat Rattanavayakorn--------------
#-----Main-----
install_path=/app				# Mandatory
java_file=auto					# Mandatory [auto|<filename>] (Blank if use java_link_exist)
hadoop_file=auto				# Mandatory [auto|<filename>]

link_path=						# Optional (Blank if use java_link_exist)
java_link_name=					# Optional (Blank if use java_link_exist)
hadoop_link_name=				# Optional

java_link_exist=				# Optional [<Full Path of JAVA Home>|<Full Path Link of JAVA Home>] (Config if already exist JAVA)

hadoop_service_type=service		# Mandatory [service|systemctl]

#------------------21_Jun_2018-------------------
#Auto set Install path
server_ip=$(hostname -I | awk '{ print $1 }')
current_path=`cd "$(dirname "$0")" && pwd`
	if [ -z $install_path ]; then
		install_path=$current_path
	fi

#Auto set JAVA file
	if [[ $java_file == auto ]] && [ -z $java_link_exist ]; then
		if [[ $(ls -pdL jdk-*.*| grep -v / | sort -r | head -n 1) ]]; then
			java_file=$(ls -pdL jdk-*.*| grep -v / | sort -r | head -n 1)
		else
			echo "Error : JAVA file not found"
			exit
		fi
	fi

#Set JAVA link name and Link path from JAVA link exist
	if [ ! -z $java_link_exist ]; then
		if [ -d $java_link_exist ] || [ -h $java_link_exist ]; then
			java_link_name=$(basename $java_link_exist)
			link_path=$(dirname $java_link_exist)
		else
			echo "Error : $java_link_exist link not found"
			exit
		fi
	else
		if [ -z $link_path ]; then
			link_path=$install_path
		fi
	fi

#Auto set Hadoop file
	if [[ $hadoop_file == auto ]]; then
		if [[ $(ls -pdL hadoop-*.*| grep -v / | sort -r | head -n 1) ]]; then
			hadoop_file=$(ls -pdL hadoop-*.*| grep -v / | sort -r | head -n 1)
		else
			echo "Error : Hadoop file not found"
			exit
		fi
	fi
hadoop_version=$(echo $hadoop_file| cut -d'-' -f 2| cut -d'.' -f 1-3)

#Check JAVA File
	if [ -z $java_link_exist ]; then
		if [ ! -z $java_file ]; then
			if [ ! -e $java_file ]; then
				echo "Error : $java_file not found"
				exit
			fi
		else
			echo "Error : JAVA file is null"
			exit
		fi
	fi

#Check Hadoop File
	if [ ! -z $hadoop_file ]; then
		if [ ! -e $hadoop_file ]; then
			echo "Error : $hadoop_file not found"
			exit
		fi
	else
		echo "Error : Hadoop file is null"
		exit
	fi

#Check Unzip for Java File and Hadoop File
	if [[ $java_file == *.zip ]] || [[ $hadoop_file == *.zip ]]; then
		if ! rpm --quiet -q unzip; then
			yum -y install unzip
		fi
	fi

#Check Netstat
	if ! rpm --quiet -q net-tools; then
		if timeout 0.2 ping -c 1 www.google.com &> /dev/null
		then
			yum -y install net-tools
		fi
	fi

#Check Hadoop Port
	if rpm --quiet -q net-tools; then
		if [[ $hadoop_version == 2.* ]];then
			if [ $(netstat -ln | grep ":50070 " > /dev/null 2>&1; echo $?) -eq 0 ]; then
				echo "Error : Hadoop port (50070) in used"
				exit
			fi
		else
			if [ $(netstat -ln | grep ":9870 " > /dev/null 2>&1; echo $?) -eq 0 ]; then
				echo "Error : Hadoop port (9870) in used"
				exit
			fi
		fi
		if [ $(netstat -ln | grep ":8088 " > /dev/null 2>&1; echo $?) -eq 0 ]; then
			echo "Error : Hadoop port (8088) in used"
			exit
		fi
	fi

#Check Hadoop Service Type
	if [[ $hadoop_service_type != service ]] && [[ $hadoop_service_type != systemctl ]]; then
		echo "Error : Hadoop service type must use \"service\" or \"systemctl\""
		exit
	fi

#Check JAVA Link
	if [ -z $java_link_exist ]; then
		if [ ! -z $java_link_name ]; then
			if [ -h $link_path/$java_link_name ]; then
				echo "Error : $link_path/$java_link_name link already exists"
				exit
			fi
		fi
	fi

#Check Hadoop Link & Service Exist
	if [ ! -z $hadoop_link_name ]; then
		if [ -h $link_path/$hadoop_link_name ]; then
			echo "Error : $link_path/$hadoop_link_name link already exists"
			exit
		fi
		case $hadoop_service_type in
			service)
				if [ -e /etc/init.d/$hadoop_link_name ]; then
					echo "Error : /etc/init.d/$hadoop_link_name already exists"
					exit
				fi
				;;
			systemctl)
				if [ -e /usr/lib/systemd/system/$hadoop_link_name.service ]; then
					echo "Error : /usr/lib/systemd/system/$hadoop_link_name.service already exists"
					exit
				fi
				;;
		esac
	else
		case $hadoop_service_type in
			service)
				if [ -e /etc/init.d/hadoop ]; then
					echo "Error : /etc/init.d/hadoop already exists"
					exit
				fi
				;;
			systemctl)
				if [ -e /usr/lib/systemd/system/hadoop.service ]; then
					echo "Error : /usr/lib/systemd/system/hadoop.service already exists"
					exit
				fi
				;;
		esac
	fi

#Create directory Install path and Link path
	if [ ! -d $install_path ]; then
		mkdir -p $install_path
	fi
	if [ -z $java_link_exist ]; then
		if [ ! -z $hadoop_link_name ] || [ ! -z $java_link_name ]; then
			if [ ! -d $link_path ]; then
				mkdir -p $link_path
			fi
		fi
	fi

#Set Hadoop Port
	if [[ $hadoop_version == 2.* ]];then
		hadoop_port=50070
	else
		hadoop_port=9870
	fi

#Allow Port Hadoop
	if [ $(ps -ef | grep -v grep | grep firewalld | wc -l) -gt 0 ]; then
		firewall-cmd --quiet --permanent --add-port=$hadoop_port/tcp
		firewall-cmd --quiet --permanent --add-port=8088/tcp
		firewall-cmd --quiet --reload
		echo "Success : Allow port $hadoop_port, 8088 complete"
	else
		echo "Warning : Firewall is not running"
	fi

#Extract JAVA File
	if [ -z $java_link_exist ]; then
		case $java_file in
			*.bin)
				echo "Launching : Extracting $java_file"
				chmod +x $java_file
				cd $install_path
				$current_path/$java_file
				cd $current_path
				echo "Success : Extracted $java_file complete"
				;;
			*.zip)
				echo "Launching : Extracting $java_file"
				unzip -q $java_file -d $install_path
				echo "Success : Extracted $java_file complete"
				;;
			*.tar.gz)
				echo "Launching : Extracting $java_file"
				tar -zxf $java_file -C $install_path
				echo "Success : Extracted $java_file complete"
				;;
			*.tar|*.tar.xz)
				echo "Launching : Extracting $java_file"
				tar -xf $java_file -C $install_path
				echo "Success : Extracted $java_file complete"
				;;
			*)
				echo "Error : $java_file is invalid"
				exit
				;;
		esac
	fi

#Set JAVA Extract
	if [ -z $java_link_exist ]; then
		case $java_file in
			jdk-6*|jdk-7*|jdk-8*)
				java_extract=jdk1.$(echo $java_file| cut -d'u' -f 1| cut -c 5-).0_$(echo $java_file| cut -d'-' -f 2| cut -c 3-)
				java_version=$(echo $java_extract| cut -d'k' -f 2)
				;;
			jdk*)
				java_extract=$(echo $java_file| cut -d'_' -f 1)
				java_version=$(echo $java_extract| cut -d'-' -f 2)
				;;
			*)
				echo "Error : Set JAVA Internal Environment"
				exit
				;;
		esac
	else
		java_extract=$(basename $(readlink -f $java_link_exist))
		java_version_temp=$($java_link_exist/bin/java -version)
		java_version=$(cat $java_version_temp | grep "java version" | awk '{ print $3 }' | cut -d'"' -f 2)
	fi

#Create Symbolic JAVA Link
	if [ -z $java_link_exist ]; then
		if [ ! -z $java_link_name ]; then
			ln -s $install_path/$java_extract $link_path/$java_link_name
			echo "Success : Create $java_link_name link complete"
		fi
	fi

#Set JAVA null variable
	if [ -z $java_link_name ]; then
		java_path=$install_path
		java_link_name=$java_extract
	else
		java_path=$link_path	
	fi

#Extract Hadoop File
	case $hadoop_file in
		*.zip)
			echo "Launching : Extracting $hadoop_file"
			unzip -q $hadoop_file -d $install_path
			echo "Success : Extracted $hadoop_file complete"
			;;
		*.tar.gz)
			echo "Launching : Extracting $hadoop_file"
			tar -zxf $hadoop_file -C $install_path
			echo "Success : Extracted $hadoop_file complete"
			;;
		*.tar)
			echo "Launching : Extracting $hadoop_file"
			tar -xf $hadoop_file -C $install_path
			echo "Success : Extracted $hadoop_file complete"
			;;
		*)
			echo "Error : $hadoop_file is invalid"
			exit
			;;
	esac

#Set Hadoop extract
hadoop_extract=$(echo $hadoop_file| cut -d'.' -f 1-3)

#Create Symbolic Hadoop Link
	if [ ! -z $hadoop_link_name ]; then
		ln -s $install_path/$hadoop_extract/ $link_path/$hadoop_link_name
		echo "Success : Create $hadoop_link_name link complete"
	fi

#Set Hadoop null variable
	if [ -z $hadoop_link_name ]; then
		link_path=$install_path
		hadoop_link_name=$hadoop_extract
		hadoop_service=hadoop
	else
		hadoop_service=$hadoop_link_name
	fi

#Create user hadoop
	if [[ $(id -u hadoop > /dev/null 2>&1; echo $?) == 1 ]]; then
		useradd hadoop
		echo "Success : Create user hadoop complete"
		echo hadoop | passwd --stdin hadoop > /dev/null
	fi

#Create public key authentication
	if [ ! -d /home/hadoop/.ssh ]; then
		su - hadoop -c 'cat /dev/zero | ssh-keygen -q -N "" > /dev/null'
		cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys
		chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
		chmod 0600 /home/hadoop/.ssh/authorized_keys
	fi

#Set JAVA bashrc
	if ! grep -q "JAVA_HOME" /home/hadoop/.bashrc; then
		echo "export JAVA_HOME=$java_path/$java_link_name
export PATH=\$PATH:\$JAVA_HOME/bin" >> /home/hadoop/.bashrc
	fi

#Set JAVA alternatives
	alternatives --install /usr/bin/java java $java_path/$java_link_name/bin/java 2
	alternatives --install /usr/bin/javac javac $java_path/$java_link_name/bin/javac 2
	alternatives --install /usr/bin/jar jar $java_path/$java_link_name/bin/jar 2
	alternatives --set java $java_path/$java_link_name/bin/java
	alternatives --set javac $java_path/$java_link_name/bin/javac
	alternatives --set jar $java_path/$java_link_name/bin/jar
	alternatives --config java <<< '' | > /dev/null
	echo "Success : Set java alternatives complete"

#Config Hadoop Environment
	if ! grep -q "HADOOP" /home/hadoop/.bashrc; then
		echo "export HADOOP_HOME=$link_path/$hadoop_link_name
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_INSTALL/lib/native\"" >> /home/hadoop/.bashrc
	fi
	sed -i "s@# export JAVA_HOME=@export JAVA_HOME=$java_path/$java_link_name@" $link_path/$hadoop_link_name/etc/hadoop/hadoop-env.sh
	sed -i '/<configuration>/a<property>\n<name>fs.default.name</name>\n<value>hdfs://localhost:9000</value>\n</property>' $link_path/$hadoop_link_name/etc/hadoop/core-site.xml
	sed -i '/<configuration>/a<property>\n<name>dfs.replication</name>\n<value>1</value>\n</property>\n\n<property>\n<name>dfs.name.dir</name>\n<value>file:///home/hadoop/hadoopinfra/hdfs/namenode </value>\n</property>\n\n<property>\n<name>dfs.data.dir</name>\n<value>file:///home/hadoop/hadoopinfra/hdfs/datanode </value>\n</property>' $link_path/$hadoop_link_name/etc/hadoop/hdfs-site.xml
	sed -i '/<configuration>/a<property>\n<name>yarn.nodemanager.aux-services</name>\n<value>mapreduce_shuffle</value>\n</property>' $link_path/$hadoop_link_name/etc/hadoop/yarn-site.xml
	if [ ! -e $link_path/$hadoop_link_name/etc/hadoop/mapred-site.xml ]; then
		cp $link_path/$hadoop_link_name/etc/hadoop/mapred-site.xml.template $link_path/$hadoop_link_name/etc/hadoop/mapred-site.xml
	fi
	sed -i '/<configuration>/a<property>\n<name>mapreduce.framework.name</name>\n<value>yarn</value>\n</property>' $link_path/$hadoop_link_name/etc/hadoop/mapred-site.xml
	echo "Success : Config hadoop complete"

#Change Permission Owner Hadoop
	chown -R hadoop:hadoop $install_path/$hadoop_extract/

#Create Service Hadoop
case $hadoop_service_type in
	service)
		echo "#! /bin/bash
#
# hadoop          Start/Stop Hadoop
#
# chkconfig: 2345 95 65
# description: Hadoop is a java based
# processname: hadoop
HADOOP_HOME=$link_path/$hadoop_link_name
start() {
        echo -n \$\"Starting Hadoop \"
        su - hadoop -c \$HADOOP_HOME/sbin/start-all.sh
}
stop() {
        echo -n \$\"Stopping Hadoop \"
        su - hadoop -c \$HADOOP_HOME/sbin/stop-all.sh
}
restart() {
        stop
        start
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
        ps ax | grep \$HADOOP_HOME
        ;;
  *)
        echo \$\"Usage: \$0 {start|stop|status|restart}\"
        exit 1
esac
exit 0" > /etc/init.d/$hadoop_service
		chmod +x /etc/init.d/$hadoop_service
		chkconfig --add $hadoop_service
		service_start="service $hadoop_service start"
		service_stop="service $hadoop_service stop"
		service_file="/etc/init.d/$hadoop_service"
		echo "Success : Created service /etc/init.d/$hadoop_service complete"
		su - hadoop -c "ssh -o StrictHostKeyChecking=no hadoop@localhost \"exit\""
		su - hadoop -c "ssh -o StrictHostKeyChecking=no hadoop@0.0.0.0 \"exit\""
		su - hadoop -c 'hdfs namenode -format'
		su - hadoop -c 'start-dfs.sh'
		su - hadoop -c 'start-yarn.sh'
		;;
	systemctl)
		echo "# Systemd unit file for hadoop
[Unit]
Description=Apache Hadoop
After=syslog.target network.target remote-fs.target nss-lookup.target network-online.target
Requires=network-online.target

[Service]
Type=forking
User=hadoop
Group=hadoop
ExecStart=$link_path/$hadoop_link_name/sbin/start-all.sh
ExecStop=$link_path/$hadoop_link_name/sbin/stop-all.sh
Environment=JAVA_HOME=$java_path/$java_link_name
Environment=HADOOP_HOME=$link_path/$hadoop_link_name

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/$hadoop_service.service
		systemctl -q enable $hadoop_service.service
		service_start="systemctl start $hadoop_service"
		service_stop="systemctl stop $hadoop_service"
		service_file="/usr/lib/systemd/system/$hadoop_service.service
                                : /etc/systemd/system/multi-user.target.wants/$hadoop_service.service"
		echo "Success : Created service /usr/lib/systemd/system/$hadoop_service.service complete"
		su - hadoop -c "ssh -o StrictHostKeyChecking=no hadoop@localhost \"exit\""
		su - hadoop -c "ssh -o StrictHostKeyChecking=no hadoop@0.0.0.0 \"exit\""
		su - hadoop -c 'hdfs namenode -format'
		systemctl start $hadoop_service
		systemctl status $hadoop_service
		;;
esac

#Create Hadoop Detail
echo "~~~~~~~~~~~~~~~~~~~~~Apache Hadoop~~~~~~~~~~~~~~~~~~~~
Hadoop Version                  : $hadoop_version
Hadoop Install Path             : $link_path/$hadoop_link_name
Hadoop Config Path              : $link_path/$hadoop_link_name/etc/hadoop
Hadoop Logs Path                : $link_path/$hadoop_link_name/logs
Hadoop Check Components Command : jps
Hadoop HDFS Command             : hdfs dfs (-command)
Hadoop Port                     : $hadoop_port, 8088
Hadoop NameNode Page            : http://$server_ip:$hadoop_port
Hadoop ResourceManager Page     : http://$server_ip:8088
Hadoop Start Service            : $service_start
Hadoop Stop Service             : $service_stop
Hadoop File Service             : $service_file

~~~~~~~~~~~~~~~~~~~~~~~~~JAVA~~~~~~~~~~~~~~~~~~~~~~~~~
JAVA Version                    : $java_version
JAVA Install Path               : $java_path/$java_link_name

~~~~~~~~~~~~~~~~~~~~~~~~Server~~~~~~~~~~~~~~~~~~~~~~~~
OS Username                     : hadoop
OS Password                     : hadoop
Home Directory                  : /home/hadoop

$(date | awk '{ print $3 }')-$(date | awk '{ print $2 }')-$(date | awk '{ print $6 }') $(date +%r)
~~~~~~~~~~~~~~~~~Created by Ponlawat Rattanavayakorn~~~~~~~~~~~~~~~~~" > $link_path/$hadoop_link_name/Hadoop_Detail.txt
#---End---
echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Notice~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Note : Created File $link_path/$hadoop_link_name/Hadoop_Detail.txt\n"
cat $link_path/$hadoop_link_name/Hadoop_Detail.txt
echo "Bye (^-^)/~~~~~~~~~~~~~~~~~~~~"
su - hadoop
exit 0