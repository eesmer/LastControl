#!/bin/bash

#------------------
# Color Codes
#------------------
MAGENTA="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
DGREEN="tput setaf 4"
CYAN="tput setaf 6"
WHITE="tput setaf 7"
GRAY="tput setaf 8"
RED="tput setaf 9"
NOCOL="tput sgr0"

WDIR=/usr/local/lastcontrol
RDIR=$WDIR/reports
CREATE=$WDIR/scripts/lctuiscripts/create-tui-report-linux.sh
RPTLIN=$WDIR/scripts/linux/create-report-linux.sh
MACHINESCRIPT=/usr/local/lastcontrol/scripts/machinescripts
PDFSTORE=$RDIR/pdfreports
PDFREPORTS=/var/www/html/reports
BOARDFILE=/usr/local/lastcontrol/doc/board.txt

NWADAPTER=$(ip r | grep onlink | cut -d " " -f5)
HOSTIP=$(hostname -I | xargs)
HOSTOS=$(hostnamectl | grep "Operating System" | cut -d ":" -f2 | xargs)
HOSTHNAME=$(cat /etc/hostname)

mkdir -p $PDFSTORE

function pause(){
local message="$@"
[ -z $message ] && message="Press Enter to continue"
read -p "$message" readEnterKey
}

function show_menu(){
#BOARDMSG=$(cat $BOARDFILE)
MACHDATE=$(date)
echo -e "\e[1;37;1m$MACHDATE\e[0m"
pwd
echo "------------------------------"
BANNERCOLOR=$((1 + "$RANDOM" % 9))
tput setaf "$BANNERCOLOR"
cat $WDIR/doc/banner.txt
echo ""
$RED
echo "    V2 Update:28"
echo "    $HOSTOS - IP: $HOSTIP"
$GRAY
$NOCOL
echo "   |------------------------------------------------------------------|"
echo "   | # REPORT MENU #                                                  |"
echo "   |------------------------------------------------------------------|"
echo "   | 1.System  Report   | 6.Local User Report  | 11.Process Report    |"
echo "   | 2.Service Report   | 7.Inventory Report   | 12.Directory Report  |"
echo "   | 3.Disk    Report   | 8.Update Report      | 13.Apps. Report      |"
echo "   | 4.Network Report   | 9.Kernel Report      | 14.SUID SGID Report  |"
echo "   | 5.SSH     Report   | 10.Unsecure Packages | 15.Repository Report |"
echo "   |------------------------------------------------------------------|"
echo "   | # MACHINE MENU #                                                 |"
echo "   |------------------------------------------------------------------|"
echo "   | 50.Take all Report |                                             |"
echo "   |------------------------------------------------------------------|"
echo "   | 30. Add    Machine | 32. Machine List                            |"
echo "   | 31. Remove Machine |                                             |"
echo "   |------------------------------------------------------------------|"
echo "   | 40. Add SSH-Key    | 41. Remove SSH-Key                          |"
echo "   |------------------------------------------------------------------|"
#$RED
#echo "                             -----------                               "
#echo "                             ** BOARD **                               "
#echo "                             -----------                               "
#$MAGENTA
#$NOCOL
#echo "     $BOARDMSG                                                         "
echo "    Download Reports: http://$HOSTIP/pdfreports                        "
echo "   --------------------------------------------------------------------"
echo ""
echo "    -----------"
echo "    | 99.Exit |"
echo "    -----------"
echo -e
}

function create_system_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
	kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating System Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null # The above check makes this check unnecessary. It will not be removed for now.
		if [ "$?" = "0" ]; then
			bash $RPTLIN systemreport $TARGETMACHINE
			$WHITE
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-systemreport.txt
			$NOCOL
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-systemreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-systemreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-systemreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-systemreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-systemreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE System Report" > $BOARDFILE
			pause
		else
			$GREEN
			echo "Could not reach $TARGETMACHINE from Port 22"
			$NOCOL
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_service_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Service Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN servicereport $TARGETMACHINE
			$WHITE
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.txt
			$NOCOL
			echo ""
			
			# adding listening services output image
			# cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-listeningservice.txt | grep -v "tcp6" | convert label:@- /tmp/$TARGETMACHINE-listeningservices.png
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "\newpage" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "## Listening Service List ##" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			# echo "![](/tmp/$TARGETMACHINE-listeningservices.png){ width=80% }" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "---" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
		
			# adding established services output image
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-establishedservice.txt | convert label:@- /tmp/$TARGETMACHINE-establishedservices.png
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			###echo "\newpage" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "## Established Service List ##" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "![](/tmp/$TARGETMACHINE-establishedservices.png){ width=80% }" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			echo "---" >> $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-servicereport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-servicereport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.txt $PDFREPORTS/$TARGETMACHINE/
			#cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-servicereport.json $PDFREPORTS/$TARGETMACHINE/

			echo "Info: Generated $TARGETMACHINE Service Report" > $BOARDFILE
			pause
		else
			$GREEN
			echo "Could not reach $TARGETMACHINE from Port 22"
			$NOCOL
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_disk_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
	kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Local Disk Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN diskreport $TARGETMACHINE
			$WHITE
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-diskreport.txt
			$NOCOL
            echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-diskreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-diskreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-diskreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-diskreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-diskreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Disk Report" > $BOARDFILE
			pause
		else
			$GREEN
			echo "Could not reach $TARGETMACHINE from Port 22"
			$NOCOL
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_nwconfig_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Network Config Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN nwconfigreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-nwconfigreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-nwconfigreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-nwconfigreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-nwconfigreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-nwconfigreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-nwconfigreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Network Config Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_ssh_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating SSH Config Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN sshreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-sshreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-sshreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-sshreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-sshreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-sshreport.txt $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE SSH Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_localuser_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Local User Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN localuserreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-localuserreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-localuserreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-localuserreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-localuserreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-localuserreport.txt $PDFREPORTS/$TARGETMACHINE/
			echo "Info: Generated $TARGETMACHINE Local User Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_inventory_report(){
        read -p "Enter the Machine Hostname : " TARGETMACHINE
        echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Hardware Inventory Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN inventoryreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-inventoryreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-inventoryreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-inventoryreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-inventoryreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-inventoryreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-inventoryreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Inventory Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_update_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating System Update Report... ..::"
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN updatereport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-updatereport.txt
			tput sgr 0
			echo ""
			echo "Info: Generated $TARGETMACHINE Update Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_kernel_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Kernel Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN kernelreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-kernelreport.txt
			tput sgr 0
			echo ""
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-kernelreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-kernelreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-kernelreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-kernelreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-kernelreport.json $PDFREPORTS/$TARGETMACHINE/
			echo "Info: Generated $TARGETMACHINE Kernel Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_unsecurepack_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
	kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Unsecure Package Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN unsecurepackreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-unsecurepackreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-unsecurepackreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-unsecurepackreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-unsecurepackreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-unsecurepackreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-unsecurepackreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Unsecure Package Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_process_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Process & Load Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN processreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-processreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-processreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-processreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-processreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-processreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-processreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Process Report" > $BOARDFILE
			pause
		else
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_directory_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
	kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Directory Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN directoryreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-directoryreport.txt
			tput sgr 0
			echo ""
			
			pandoc -s -o $PDFSTORE/$TARGETMACHINE-directoryreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-directoryreport.md
			mkdir -p $PDFREPORTS/$TARGETMACHINE
			cp $PDFSTORE/$TARGETMACHINE-directoryreport.pdf $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-directoryreport.txt $PDFREPORTS/$TARGETMACHINE/
			cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-directoryreport.json $PDFREPORTS/$TARGETMACHINE/
			
			echo "Info: Generated $TARGETMACHINE Directory Report" > $BOARDFILE
			pause
		else
			
			tput setaf 2
			echo "Could not reach $TARGETMACHINE from Port 22"
			tput sgr 0
			echo -e
			pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
		echo -e
		echo "[ Error ]"
		echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
		echo -e
		$GREEN
		echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
		$NOCOL
		echo -e
		pause
	fi
}

function create_apps_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
	ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
	PID=$!
	sleep 1
	kill $PID
	if [ "$?" = 1 ]; then
		$RED
		echo "::.. Generating Applications Report... ..::"
		echo ""
		nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
		if [ "$?" = "0" ]; then
			bash $RPTLIN appsreport $TARGETMACHINE
			tput setaf 7
			echo ""
			cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-appsreport.txt
			tput sgr 0
			echo ""

			pandoc -s -o $PDFSTORE/$TARGETMACHINE-appsreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-appsreport.md
                        mkdir -p $PDFREPORTS/$TARGETMACHINE
                        cp $PDFSTORE/$TARGETMACHINE-appsreport.pdf $PDFREPORTS/$TARGETMACHINE/
                        cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-appsreport.txt $PDFREPORTS/$TARGETMACHINE/
                        cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-appsreport.json $PDFREPORTS/$TARGETMACHINE/

			echo "Info: Generated $TARGETMACHINE Applications Report" > $BOARDFILE
                        pause
		else
			tput setaf 2
                        echo "Could not reach $TARGETMACHINE from Port 22"
                        tput sgr 0
                        echo -e
                        pause
		fi
	else # The password prompt returns 0. In this check, else also works outside of 0.
		$RED
                echo -e
                echo "[ Error ]"
                echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
                echo -e
                $GREEN
                echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
                $NOCOL
                echo -e
                pause
        fi
}

function create_suidsgid_report(){
	read -p "Enter the Machine Hostname : " TARGETMACHINE
	echo ""
        ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
                $RED
                echo "::.. Generating SUID and SGID Files Report... ..::"
                echo ""
                nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
                if [ "$?" = "0" ]; then
                        bash $RPTLIN suidsgidreport $TARGETMACHINE
                        tput setaf 7
                        echo ""
                        cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-suidsgidreport.txt
                        tput sgr 0
                        echo ""

                        pandoc -s -o $PDFSTORE/$TARGETMACHINE-suidsgidreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-suidsgidreport.md
                        mkdir -p $PDFREPORTS/$TARGETMACHINE
                        cp $PDFSTORE/$TARGETMACHINE-suidsgidreport.pdf $PDFREPORTS/$TARGETMACHINE/
                        cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-suidsgidreport.txt $PDFREPORTS/$TARGETMACHINE/
                        cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-suidsgidreport.json $PDFREPORTS/$TARGETMACHINE/

                        echo "Info: Generated $TARGETMACHINE SUID and SGID Report" > $BOARDFILE
                        pause
                else
                        tput setaf 2
                        echo "Could not reach $TARGETMACHINE from Port 22"
                        tput sgr 0
                        echo -e
                        pause
                fi
        else # The password prompt returns 0. In this check, else also works outside of 0.
                $RED
                echo -e
                echo "[ Error ]"
                echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
                echo -e
                $GREEN
                echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
                $NOCOL
                echo -e
                pause
	fi
}

function create_repository_report(){
        read -p "Enter the Machine Hostname : " TARGETMACHINE
        echo ""
        ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$TARGETMACHINE &
        PID=$!
        sleep 1
        kill $PID
        if [ "$?" = 1 ]; then
                $RED
                echo "::.. Generating Repository Report... ..::"
                echo ""
                nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
                if [ "$?" = "0" ]; then
                        bash $RPTLIN repositoryreport $TARGETMACHINE
                        tput setaf 7
                        echo ""
                        cat $RDIR/$TARGETMACHINE/$TARGETMACHINE-repositoryreport.txt
                        tput sgr 0
                        echo ""

                        #pandoc -s -o $PDFSTORE/$TARGETMACHINE-repositoryreport.pdf $RDIR/$TARGETMACHINE/$TARGETMACHINE-repositoryreport.md
                        #mkdir -p $PDFREPORTS/$TARGETMACHINE
                        #cp $PDFSTORE/$TARGETMACHINE-repositoryreport.pdf $PDFREPORTS/$TARGETMACHINE/
                        cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-repositoryreport.txt $PDFREPORTS/$TARGETMACHINE/
                        #cp $RDIR/$TARGETMACHINE/$TARGETMACHINE-repositoryreport.json $PDFREPORTS/$TARGETMACHINE/

                        echo "Info: Generated $TARGETMACHINE Repository Report" > $BOARDFILE
                        pause
                else
                        tput setaf 2
                        echo "Could not reach $TARGETMACHINE from Port 22"
                        tput sgr 0
                        echo -e
                        pause
                fi
        else # The password prompt returns 0. In this check, else also works outside of 0.
                $RED
                echo -e
                echo "[ Error ]"
                echo "LastControl SSH-Key Not Found on $TARGETMACHINE"
                echo -e
                $GREEN
                echo "You can add the LastControl SSH-Key from menu 40.Add SSH-Key"
                $NOCOL
                echo -e
                pause
        fi
}

#function take_all_report(){
#$RED
#echo "Generating all report for all machine.."
#echo ""
#echo ""
#$NOCOL
#
#systemctl restart lastcontrol.service
#watch -en 1 systemctl status lastcontrol.service
#systemctl disable lastcontrol.service
#
#echo "Info: All Report generated." > $BOARDFILE
#pause
#}

function add_machine(){
$RED
echo "Adding a New Machine"
echo ""
$NOCOL

read -p "Enter the Machine Hostname : " TARGETMACHINE
LISTED=FALSE
ack "$TARGETMACHINE" $WDIR/linuxmachine >> /dev/null && LISTED=TRUE

if [ "$LISTED" = FALSE ]; then
	echo "$TARGETMACHINE" >> $WDIR/linuxmachine
	echo "Info: $TARGETMACHINE added to Machine List" > $BOARDFILE
else
	$RED
	echo "$TARGETMACHINE already exist"
	$NOCOL
fi

echo ""
$GREEN
echo "::. Machine List ::."
echo "--------------------"
$NOCOL
cat $WDIR/linuxmachine
$GREEN
echo "--------------------"
$NOCOL
echo ""
pause
}

function remove_machine(){
echo ""
$GREEN
echo "Removing Machine"
echo ""
$NOCOL

read -p "Enter the Machine Hostname : " TARGETMACHINE
sed -i "/$TARGETMACHINE/d" $WDIR/linuxmachine

echo ""
$GREEN
echo "::. Machine List ::."
echo "--------------------"
$NOCOL
cat $WDIR/linuxmachine
$GREEN
echo "--------------------"
$NOCOL
echo ""
echo "Info: Removed $TARGETMACHINE from Machine List" > $BOARDFILE
pause
}

function machine_list(){
echo ""
$GREEN
echo "::. Machine List ::."
echo "--------------------"
$NOCOL
cat $WDIR/linuxmachine
$GREEN
echo "--------------------"
$NOCOL
echo ""
pause
}

function add_sshkey(){
echo ""
read -p "Enter the Machine Hostname : " TARGETMACHINE
nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
if [ "$?" = "0" ]; then
	bash $MACHINESCRIPT/add-sshkey.sh $TARGETMACHINE
	echo "Info: SSH-Key added to $TARGETMACHINE" > $BOARDFILE
	pause
else
	tput setaf 2
	echo "Could not reach $TARGETMACHINE from Port 22"
	tput sgr 0
	echo -e
	pause
fi
}

function remove_sshkey(){
echo ""
read -p "Enter the Machine Hostname : " TARGETMACHINE
nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
if [ "$?" = "0" ]; then
	KEYCONTENT=$(cat /root/.ssh/lastcontrol.pub | cut -d " " -f2 | cut -c 1-25)
	bash $MACHINESCRIPT/remove-sshkey.sh $TARGETMACHINE $KEYCONTENT
	echo "Info: SSH-Key removed to $TARGETMACHINE" > $BOARDFILE
	pause
else
	tput setaf 2
	echo "Could not reach $TARGETMACHINE from Port 22"
	tput sgr 0
	echo -e
	pause
fi
}

function take_allreport(){
echo ""
read -p "Enter the Machine Hostname : " TARGETMACHINE
nc -z -w 2 $TARGETMACHINE 22 2>/dev/null
if [ "$?" = "0" ]; then
    bash $MACHINESCRIPT/allreport.sh $TARGETMACHINE
    echo "Info: All Report run for $TARGETMACHINE" > $BOARDFILE
    pause
fi
}

function read_input(){
$WHITE
local c
read -p "You can choose from the menu numbers " c
$NOCOL
case $c in
1) create_system_report ;;
2) create_service_report ;;
3) create_disk_report ;;
4) create_nwconfig_report ;;
5) create_ssh_report ;;
6) create_localuser_report ;;
7) create_inventory_report ;;
8) create_update_report ;;
9) create_kernel_report ;;
10) create_unsecurepack_report ;;
11) create_process_report ;;
12) create_directory_report ;;
13) create_apps_report ;;
14) create_suidsgid_report ;;
15) create_repository_report ;;
30) add_machine ;;
31) remove_machine ;;
32) machine_list ;;
40) add_sshkey ;;
41) remove_sshkey ;;
50) take_allreport ;;
99) exit 0 ;;
*)
$MAGENTA
echo "Please select from the menu numbers"
$NOCOL
pause
esac
}

# CTRL+C, CTRL+Z
trap '' SIGINT SIGQUIT SIGTSTP

while true
do
clear
show_menu
read_input
done
