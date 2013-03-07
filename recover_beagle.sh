#!/bin/bash
DIR=`dirname $0`
cd $DIR
usage(){
	echo "Usage: $0 ttyPort"
	echo "Required - sudo permissions, beagleboard, 1 usb and 1 uart cable"
	echo "USB MUST BE CONNECTED ON PC PORT directly (NOT THROUGH AN HUB)!!!!"
}
if [ $# -lt 1 ]; then
	usage
	exit -1
fi
export TTY=$1
for i in ./ucmd ./ukermit ./pusb
do
	if [ ! -x $i ]; then
		echo "Unable to find executable file $i in $DIR";
		exit 1
	fi
done
for i in ./target_files/u-boot-v2.bin target_files/x-load.bin.ift ./target_files/u-boot-v2.bin
do
	if [ ! -r $i ]; then
		echo "Unable to find file $i in $DIR";
		exit 2
	fi
done

if [ ! -r "$TTY" -o ! -w "$TTY" ]; then
	echo "Unable to use serial port: $TTY"
	usage
	exit 3
fi
lsof "$TTY"
if [ $? -ne 1 ]; then
	echo "Please cleanup apps holding serial port!!!"
	exit 4
fi
echo "NOTE:"
echo "CRITICAL: USB MUST BE CONNECTED ON PC PORT directly (NOT THROUGH AN HUB)!!!!"
echo "CRITICAL: POLLING MODE USED - try NOT TO have CPU intensive tasks going on in background"
echo "Keep S1 pressed for 1 second at least after connecting usb cable."
usb_usage=1
if [ $usb_usage -eq 1 ]; then
	# USB does not always work :(
	echo 'When you see the message "Waiting for USB device..", Connect USB Cable to the board with the switch S1 pressed'
	sudo ./pusb -f ./target_files/u-boot-v2.bin 
	if [ $? -ne 0 ]; then
		echo "unable to run pusb"
		exit 4
	fi
else
	# Trying serial - may or maynot work...??
	sudo stty -F $TTY 1:0:18b2:0:3:1c:7f:15:1:5:1:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0
	if [ $? -ne 0 ]; then
		echo "unable to run stty"
		exit 4
	fi
	sudo ./pserial -p $TTY -f ./target_files/u-boot-v2.bin 
	if [ $? -ne 0 ]; then
		echo "unable to run pserial"
		exit 4
	fi
	sudo stty -F $TTY 1:0:18b2:0:3:1c:7f:15:1:5:1:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0
	if [ $? -ne 0 ]; then
		echo "unable to run pserial"
		exit 4
	fi
fi

sleep 1
./ucmd -p $TTY -c "loadb -f /dev/ram0" -e "bps..."
if [ $? -ne 0 ]; then
	echo "unable to run load with u-boot v2"
	exit 5
fi
./ukermit -p $TTY -f target_files/u-boot-v1.bin 
if [ $? -ne 0 ]; then
	echo "ukermit failed loading u-boot-v1!"
	exit 6
fi
./ucmd -p $TTY -c "go 0x80000000" -e "serial";./ucmd -p $TTY -c "help" -e "#"
if [ $? -ne 0 ]; then
	echo "Unable to run u-boot v1!"
	exit 7
fi
./ucmd -p $TTY -c "nand erase" -e "#"
if [ $? -ne 0 ]; then
	echo "unable to erase the flash"
	exit 8
fi
./ucmd -p $TTY -c "nand write.i 80000000 80000 80000" -e "#"
if [ $? -ne 0 ]; then
	echo "Unable to write u-boot-v1"
	exit 9
fi
./ucmd -p $TTY -c "loadb 80000000" -e "bps..."
if [ $? -ne 0 ]; then
	echo "unable to run loadb again "
	exit 10
fi
./ukermit -p $TTY -f target_files/x-load.bin.ift 
if [ $? -ne 0 ]; then
	echo "failed to run kermit x-loader file"
	exit 11
fi
./ucmd -p $TTY -c "nandecc hw" -e "#"
if [ $? -ne 0 ]; then
	echo "did not set hw ecc"
	exit 12
fi
./ucmd -p $TTY -c "nand write.i 80000000 0 80000" -e "#"
if [ $? -ne 0 ]; then
	echo "unable to flash x-loader"
	exit 13
fi
#
# The following step is optional really..
./ucmd -p $TTY -c "setenv bootcmd;nandecc sw;saveenv" -e "#"
if [ $? -ne 0 ]; then
	echo "unable to setenv"
	exit 14
fi
