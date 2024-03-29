#!/bin/bash

vivado_ver="2020.2"
nfplus="${HOME}/NetFPGA-100G-alpha"
vivado="/tools/Xilinx/Vivado/2020.2/settings64.sh"

if [ ! -d ${nfplus} ]; then
	echo "Error: ${nfplus} not found."
	echo "Please check NF_REPO variable on this script."
fi

if [ ! -f ${vivado} ]; then
	if [ -f /tools/Xilinx/Vivado/${vivado_ver}/settings64.sh ]; then
		vivado="/tools/Xilinx/Vivado/${vivado_ver}/settings64.sh"
	elif [ -f /opt/Xilinx/Vivado/${vivado_ver}/settings64.sh ]; then
		vivado="/opt/Xilinx/Vivado/${vivado_ver}/settings64.sh"
	else
		echo "Error: ${vivado} not found."
		echo "Please check xilinx_path variable on this script."
		exit -1
	fi
fi

source $vivado

source $nfplus/tools/settings.sh

sudo chown -R ${USER}:${USER} $nfplus
cd $nfplus
make

export NF_PROJECT_NAME=reference_switch
export NF_DESIGN_DIR=${NFPLUS_FOLDER}/hw/projects/${NF_PROJECT_NAME}

make -C $NF_DESIGN_DIR/hw clean
make -C $NF_DESIGN_DIR/hw
cp $NF_DESIGN_DIR/hw/vivado.log ${NF_PROJECT_NAME}.log

export NF_PROJECT_NAME=reference_switch_lite
export NF_DESIGN_DIR=${NFPLUS_FOLDER}/hw/projects/${NF_PROJECT_NAME}

make -C $NF_DESIGN_DIR/hw clean
make -C $NF_DESIGN_DIR/hw
cp $NF_DESIGN_DIR/hw/vivado.log ${NF_PROJECT_NAME}.log

export NF_PROJECT_NAME=reference_nic
export NF_DESIGN_DIR=${NFPLUS_FOLDER}/hw/projects/${NF_PROJECT_NAME}

make -C $NF_DESIGN_DIR/hw clean
make -C $NF_DESIGN_DIR/hw
cp $NF_DESIGN_DIR/hw/vivado.log ${NF_PROJECT_NAME}.log

export NF_PROJECT_NAME=reference_router
export NF_DESIGN_DIR=${NFPLUS_FOLDER}/hw/projects/${NF_PROJECT_NAME}

make -C $NF_DESIGN_DIR/hw clean
make -C $NF_DESIGN_DIR/hw
cp $NF_DESIGN_DIR/hw/vivado.log ${NF_PROJECT_NAME}.log

res_switch=$(cat ${NFPLUS_FOLDER}/hw/projects/reference_switch/hw/vivado.log | tail -n 10 | grep -v "#")
res_switch_lite=$(cat ${NFPLUS_FOLDER}/hw/projects/reference_switch/hw/vivado.log | tail -n 10 | grep -v "#")
res_nic=$(cat ${NFPLUS_FOLDER}/hw/projects/reference_nic/hw/vivado.log | tail -n 10 | grep -v "#")
res_router=$(cat ${NFPLUS_FOLDER}/hw/projects/reference_router/hw/vivado.log | tail -n 10 | grep -v "#")

echo "All task was done..."
echo "reference_switch:"
echo ${res_switch}
echo ""
echo "reference_switch_lite:"
echo ${res_switch_lite}
echo ""
echo "reference_nic:"
echo ${res_nic}
echo ""
echo "reference_router:"
echo ${res_router}
