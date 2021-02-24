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
bitfile_sw_lite="${NF_REPO}/hw/projects/reference_switch/bitfiles/reference_switch_${device}.bit"
bitfile_nic="${NF_REPO}/hw/projects/reference_switch/bitfiles/reference_switch_${device}.bit"
bitfile_router="${NF_REPO}/hw/projects/reference_switch/bitfiles/reference_switch_${device}.bit"
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
	echo "./reproduction-test <switch|switch_lite|nic|router>"
}

function network_setup(){
	sudo ifconfig nf0 up
	sudo ifconfig nf1 up
	sudo ifconfig $ifname0 up
	sudo ifconfig $ifname1 up
}

function load_driver(){
	if [! test -n "$(grep -e onic /proc/modules)" ]; then
		if [ ! -f ${NF_REPO}/sw/driver/OpenNIC/onic.ko ]; then
			cd ${NF_REPO}/sw/driver && make clean && make
		fi
		sudo insmod ${NF_REPO}/sw/driver/OpenNIC/onic.ko
	fi
}

if [ -z $1 ]; then
	echo "Error: please specify 1 augument"
	usage
fi

if [ $1 = "switch" ]; then
	scenario=("${sw_scenario[@]}")
	bitfile=${bitfile_sw}
	proj="reference_switch"
elif [ $1 = "switch_lite" ]; then
	scenario=("${sw_scenario[@]}")
	bitfile=${bitfile_sw_lite}
	proj="reference_switch_lite"
elif [ $1 = "nic" ]; then
	scenario=("${nic_scenario[@]}")
	bitfile=${bitfile_nic}
	proj="reference_nic"
elif [ $1 = "router" ]; then
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
	echo "Error: ${xilinx_path} not found."
	echo "Please check xilinx_path variable on this script."
	exit -1
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
	${HOME}/xprog load ${bitfile}
	echo ""
	echo "Rescanning PCIe device"
	sudo bash ${rescan_sh}
	echo ""
	echo "Loading driver..."
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

