#!/bin/sh

clear

echo " +---------------------------------------------------------------------------------------------------------------------+"
echo " |                                                  IMPORTANT NOTES                                                    |"
echo " |                                          FILE & DIRECTORY SYNCHRONIZER                                              |"
echo " | This script installs and configures files and folders to be synchronized.                                           |"
echo " | This script must be run with maximum privileges. Run with sudo or run it as 'root'.                                 |"
echo " | This script will do:                                                                                                |"
echo " | 1.  Get the IP of other node and make controls for valid IP                                                         |"
echo " | 2.  Test passwordless login and SSH connection Control                                                              |"
echo " | 3.  Installation of wather daemon and creation of required directories                                              |"
echo " | 4.  /root/.bashrc file existance control                                                                            |"
echo " | 5.  Alias creation for watcher daemon                                                                               |"
echo " | 6.  User input for directory path that is going to be synchronized                                                  |"
echo " | 7.  Configuration file modifications according to user input                                                        |"
echo " | 8.  Start synchronization with user demand                                                                          |"
echo " | 9.  Control if synchronization daemon is running or not                                                             |"
echo " |                                                                                                                     |"
echo " | Thanks to Gregg Hernandez for Watcher daemon. https://github.com/gregghz/Watcher                                    |"
echo " +---------------------------------------------------------------------------------------------------------------------+"
echo

# check for root privilege
if [ "$(id -u)" != "0" ]; then
   echo " this script must be run as root" 1>&2
   echo
   exit 1
fi

while true; do
	read -p " > Please input other server's IP: [Ex. 192.168.1.100] [Default=192.168.1.100]: " Input
	if [ -z $Input ]
	then
		Input="192.168.1.100"
	fi
	DotCount=`echo $Input | awk -F"." '{print NF-1}'`
	FirstOctet=`echo $Input | tr "." "\n" | head -1`
	SecondOctet=`echo $Input | tr "." "\n" | head -2 | tail -1`
	ThirdOctet=`echo $Input | tr "." "\n" | head -3 | tail -1`
	FourthOctet=`echo $Input | tr "." "\n" | head -4 | tail -1`
	if [ $DotCount -eq 3 ] && [ $FirstOctet -lt 255 ] && [ $SecondOctet -lt 255 ] && [ $ThirdOctet -lt 255 ] && [ $FourthOctet -lt 255 ] && [ $FirstOctet -gt 0 ] && [ $SecondOctet -ge 0 ] && [ $ThirdOctet -ge 0 ] && [ $FourthOctet -gt 0 ]
	then
		Server_IP=${Input}
		break
	else
		if [ $FourthOctet -eq 0 ]
		then
			echo " > Your IP format is wrong. Last octet must not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -eq 0 ]
		then
			echo " > Your IP format is wrong. First octet can not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -ge 255 ] || [ $SecondOctet -ge 255 ] || [ $ThirdOctet -ge 255 ] || [ $FourthOctet -ge 255 ]
		then
			echo " > Your IP format is wrong. Octets must be less than 255. Please correct and try again. "
		fi	
		
		if [ $FirstOctet -lt 0 ] || [ $SecondOctet -lt 0 ] || [ $ThirdOctet -lt 0 ] || [ $FourthOctet -lt 0 ]
		then
			echo " > Your IP format is wrong. Octets can not be negative numbers. Please correct and try again. "
		fi
	fi
done
Connection_OK=0
while true; do
	read -p " > Did you configure passwordless login? [y/n] " Answer
	case $Answer in
		[Yy]* )
				echo " > SSH connection will be tested to IP: "${Server_IP}
				Connection_OK=`ssh root@${Server_IP} "uname -a | wc -l"`
				if [ ${Connection_OK} -eq 1 ]
				then
					echo " > SSH connection with passwordless login test is successfull."
					break
				else
					echo " > Connection could not be established! Please control and then restart this script."
					echo " > Script interrupted..."
					exit 2
				fi
				;;
		[Nn]* ) 
				echo " > Passwordless login is the obligated requirement for this process. Please configure and then restart this script."
				echo " > Script interrupted..."
				exit 2
				;;
		* )
				echo " Please answer [y]es or [n]o.";;
	esac
done
echo " > Required packages will be installed."
apt-get -y install git
apt-get -y install python python-pyinotify python-yaml
mkdir /root/tools
cd /root/tools
git clone https://github.com/greggoryhz/Watcher.git
mkdir /root/.watcher
if [ -f /root/tools/Watcher/watcher.py ] && [ -f /root/tools/Watcher/jobs.yml ]
then
	echo " > Package installation completed."
else
	echo " > A problem occured. Some files missing."
	echo " > Script interrupted."
	exit 2
fi

BASHRC_FILE="/root/.bashrc"

if [ ! -f "${BASHRC_FILE}" ]
then
	echo " > $BASHRC_FILE could not be found. Aliases for watcher daemon could not be created."
	echo " > Due to absence of .bashrc file please notice:"
	echo "                                                 start synchronization with command: '/root/tools/Watcher/watcher.py start'"
	echo "                                                 stop synchronization with command:  '/root/tools/Watcher/watcher.py stop'"
else
	echo "alias wstart='/root/tools/Watcher/watcher.py start'" >> ${BASHRC_FILE}
	echo "alias wstop='/root/tools/Watcher/watcher.py stop'" >> ${BASHRC_FILE}
	. ${BASHRC_FILE}
fi

cp /root/tools/Watcher/jobs.yml /root/.watcher/

echo " > Which directory do you want to get synchronized?"
read -p " > Do not give relative path! [ Ex. /data/directory/My_Mails ] " Directory

echo "Directory="$Directory
if [ ! -d "$Directory" ]
then
	mkdir ${Directory}
fi
ssh root@${Server_IP} "mkdir -p ${Directory}"
JOBS_FILE="/root/.watcher/jobs.yml"
Directory_For_Sed=`echo ${Directory//\//\\/}`
echo "Directory_For_Sed="$Directory_For_Sed

sed -i -r "s/label: Watch/#label: Watch/g" "$JOBS_FILE"
echo "  label: Watch "${Directory}" for added or removed files" >> ${JOBS_FILE}

sed -i -r "s/watch: \/var\/www/#watch: \/var\/www/g" "$JOBS_FILE"
echo "  watch: "${Directory} >> ${JOBS_FILE}


sed -i -r "s/command: echo /#command: echo /g" "$JOBS_FILE"
echo "  command: rsync -rtv --exclude=".*" ${Directory} root@${Server_IP}:${Directory}" >> ${JOBS_FILE}

while true; do
	read -p " > Do you want to start synchronization? [y/n]" Answer
	case $Answer in
		[yY]* )
				Alias_Control=`cat ${BASHRC_FILE} | grep -e "alias wstart" -e "alias wstop" | wc -l`
				if [ $Alias_Control -eq 2 ]
				then
					wstart
				else
					/root/tools/Watcher/watcher.py start &
				fi
				Control_Daemon=`ps -ef | grep watcher.py | grep -v grep | wc -l`
				if [ $Control_Daemon -eq 1 ]
				then
					if [ $Alias_Control -eq 2 ]
					then
						echo " > Daemon started. You can stop with command: 'wstop' with root privileges."
					else
						echo " > Daemon started. You can stop with command: '/root/tools/Watcher/watcher.py stop' with root privileges."
					fi
						echo " > Synchronization log file: /root/.watcher/watcher.log"
						echo " > Script ended..."
						rm -f /root/tools/Watcher/jobs.yml
					break
				else
					echo " > Daemon could not be started. Please control the log file: '/root/.watcher/watcher.log'"
					exit 2
				fi
				;;
		[nN]* )
				echo " > Script ended..."
				break;;
		* )
				echo " Please answer [y]es or [n]o.";;
	esac
done

