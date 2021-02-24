#!/bin/bash

ifname0="eth1"
ifname1="eth2"

me_dir=$(cd $(dirname $0); pwd)
rescan_sh="${me_dir}/pci_rescan_run.sh"

sudo bash ${rescan_sh}

sudo ifconfig nf0 up 192.168.100.1
sudo ifconfig nf1 up 192.168.200.1
sudo arp -s 192.168.100.2 11:22:33:44:55:79
sudo arp -s 192.168.200.2 11:22:33:44:55:78

sudo ifconfig ${ifname0} up 192.168.30.1
sudo ifconfig ${ifname1} up 192.168.40.1
sudo arp -s 192.168.30.2 11:22:33:44:55:76
sudo arp -s 192.168.40.2 11:22:33:44:55:75

