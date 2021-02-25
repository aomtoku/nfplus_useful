#!/bin/bash

############################################################
# User defined parameters
############################################################
ifname0="eth1"
ifname1="eth2"

NF_REPO="${HOME}/NetFPGA-100G-alpha"
xilinx_path="/opt/Xilinx/Vivado/2019.2/settings64.sh"
device="au280"

bitfile_sw="${NF_REPO}/hw/projects/reference_switch/bitfiles/reference_switch_${device}.bit"
bitfile_sw_lite="${NF_REPO}/hw/projects/reference_switch_lite/bitfiles/reference_switch_lite_${device}.bit"
bitfile_nic="${NF_REPO}/hw/projects/reference_nic/bitfiles/reference_nic_${device}.bit"
bitfile_router="${NF_REPO}/hw/projects/reference_router/bitfiles/reference_router_${device}.bit"
############################################################
# Internal parameters
############################################################
me_dir=$(cd $(dirname $0); pwd)
rescan_sh="${me_dir}/pci_rescan_run.sh"
############################################################

sw_scenario=(
	"simple broadcast"
	"learning sw"
)

router_scenario=(
	"arp misses"
	"badipchksum packet"
	"invalidttl packet"
	"ipdestfilter hit"
	"lpm generic"
	"lpm misses"
	"lpm nexthop"
	"nonip packet"
	"nonipv4 packet"
	"packet forwarding"
	"router table"
	"wrong destMAC"
)

nic_scenario=(
	"loopback maxsize"
	"loopback minsize"
	"loopback random"
	"inc size"
)

function usage(){
	echo "./reproduction-test "
	echo "         -t|--target <switch|switch_lite|nic|router>"
	echo "         -d|--device <au280|au250|au200|vcu1525>"
	echo "         -p|--prefix path to NetFPGA-PLUS directory"
	echo ""
}

function network_setup(){
	nf0_if=$(ifconfig -a | grep nf0)
	nf1_if=$(ifconfig -a | grep nf1)
	if0_if=$(ifconfig -a | grep $ifname0)
	if1_if=$(ifconfig -a | grep $ifname1)
	if [ -z $nf0_if ]; then
		echo "Error: nf0 not found on network interface."
		exit -1
	else
		sudo ifconfig nf0 up
	fi
	if [ -z $nf1_if ]; then
		echo "Error: nf1 not found on network interface."
		exit -1
	else
		sudo ifconfig nf1 up
	fi
	if [ -z $if0_if ]; then
		echo "Error: ${ifname0} not found on network interface."
		exit -1
	else
		sudo ifconfig $ifname0 up
	fi
	if [ -z $if1_if ]; then
		echo "Error: ${ifname0} not found on network interface."
		exit -1
	else
		sudo ifconfig $ifname1 up
	fi
}

function load_driver(){
	onic_mod=$(grep -e onic /proc/modules)
	if [ -z "${onic_mod}" ]; then
		if [ ! -f ${NF_REPO}/sw/driver/OpenNIC/onic.ko ]; then
			cd ${NF_REPO}/sw/driver && make clean && make
		fi
		echo "Loading driver..."
		sudo insmod ${NF_REPO}/sw/driver/OpenNIC/onic.ko
	fi
}

while [[ $# -gt 0 ]]
do
arg="$1"
case $arg in
	-d|--device)
	device="$2"
	shift # past argument
	shift # past value
	;;
	-t|--target)
	target="$2"
	shift # past argument
	shift # past value
	;;
	-p|--prefix)
	NF_REPO="$2"
	shift # past argument
	shift # past value
	;;
	--default)
	DEFAULT=YES
	shift # past argument
	;;
	*)    # unknown option
	POSITIONAL+=("$1") # save it in an array for later
	shift # past argument
	;;
esac
done

bitfile_sw="${NF_REPO}/hw/projects/reference_switch/bitfiles/reference_switch_${device}.bit"
bitfile_sw_lite="${NF_REPO}/hw/projects/reference_switch_lite/bitfiles/reference_switch_lite_${device}.bit"
bitfile_nic="${NF_REPO}/hw/projects/reference_nic/bitfiles/reference_nic_${device}.bit"
bitfile_router="${NF_REPO}/hw/projects/reference_router/bitfiles/reference_router_${device}.bit"

if [ -z $target ]; then
	echo "Error: please specify 1 augument"
	usage
	exit -1
fi

if [ $target = "switch" ]; then
	scenario=("${sw_scenario[@]}")
	bitfile=${bitfile_sw}
	proj="reference_switch"
elif [ $target = "switch_lite" ]; then
	scenario=("${sw_scenario[@]}")
	bitfile=${bitfile_sw_lite}
	proj="reference_switch_lite"
elif [ $target = "nic" ]; then
	scenario=("${nic_scenario[@]}")
	bitfile=${bitfile_nic}
	proj="reference_nic"
elif [ $target = "router" ]; then
	scenario=("${router_scenario[@]}")
	bitfile=${bitfile_router}
	proj="reference_router"
else
	echo "Error: the augment is not supported"
	usage
fi

if [ ! -d ${NF_REPO} ]; then
	echo "Error: ${NF_REPO} not found."
	echo "Please check NF_REPO variable on this script."
	exit -1
fi

if [ ! -f ${xilinx_path} ]; then
	if [ -f /tools/Xilinx/Vivado/2019.2/settings64.sh ]; then
		xilinx_path="/tools/Xilinx/Vivado/2019.2/settings64.sh"
	elif [ -f /opt/Xilinx/Vivado/2019.2/settings64.sh ]; then
		xilinx_path="/opt/Xilinx/Vivado/2019.2/settings64.sh"
	else
		echo "Error: ${xilinx_path} not found."
		echo "Please check xilinx_path variable on this script."
		exit -1
	fi
fi

if [ ! -f ${bitfile} ]; then
	echo "Error: ${bitfile} not found."
	echo "Please check bitfile PATH on this script."
	exit -1
fi

if [ ! -f ${NF_REPO}/sw/app/rwaxi ]; then
	cd ${NF_REPO}/sw/app/ && make
fi

if [ -z ${XILINX_VIVADO} ]; then
	source ${xilinx_path}
fi

for scenario_data in "${scenario[@]}" ; do
	echo "Loading bitfile ${bitfile} ..."
	${me_dir}/xprog load ${bitfile}
	echo ""
	echo "Rescanning PCIe device"
	check_seq=$(sudo bash ${rescan_sh} | grep "Check programming FPGA or Reboot machine !")
	if [ ! -z "${check_seq}" ]; then
		echo "please reboot machine"
		exit -1
	fi
	sleep 1
	echo ""
	load_driver
	sleep 1
	echo ""
	echo "Network Setup..."
	network_setup

	if [ ${proj} == "reference_nic" ]; then
		echo "Setting up GT_LOOPBACK on CMAC0..."
		${NF_REPO}/sw/app/rwaxi -a 0x8090 -w 1
		echo "Setting up GT_LOOPBACK on CMAC1..."
		${NF_REPO}/sw/app/rwaxi -a 0xc090 -w 1
	fi
	d=(${scenario_data})
	major=${d[0]}
	minor=${d[1]}
	echo "major:$major minor:$minor"
	cd $NF_REPO/tools/scripts/
	sudo bash -c "source ${xilinx_path} && source ./../settings.sh && \
	     export NF_PROJECT_NAME=${proj} && \
	     export NF_DESIGN_DIR=${NF_REPO}/hw/projects/${proj} &&
	     ./nf_test.py hw --major $major --minor $minor"
done

