#!/bin/bash

# Update package list and install necessary dependencies
sudo apt update && sudo apt upgrade
sudo apt install -y strongswan frr net-tools traceroute iproute2

# Configure Dummy Loopback
LO_IP="172.16.0.10"
LO_IF="lo:1"

GRE_REMOTE_IP="172.31.0.11"   # Update per instance
GRE_LOCAL_IP="172.31.0.10"    # Update per instance
GRE_IF="gre1"

PRIMARY_BGP_NEIGHBOUR="172.16.0.11"   # IP from remote's loopback
SECONDARY_BGP_NEIGHBOUR="172.16.0.12"

# Load dummy module if not already loaded
sudo modprobe dummy

# Create dummy interface if it doesn't exist
if ! ip link show "$LO_IF" &>/dev/null; then
    sudo ip link add "$LO_IF" type dummy
fi

# Bring interface up
sudo ip link set "$LO_IF" up

# Assign loopback IP
sudo ip addr add "$LO_IP/32" dev "$LO_IF"

echo "Loopback $LO_IP added to interface $LO_IF"
# Configure FRR

# Backup the existing configuration
sudo mv /etc/frr/daemons /etc/frr/daemons.bak
sudo mv /etc/frr/frr.conf /etc/frr/frr.conf.bak

# Create a new daemons file for FRR
sudo tee /etc/frr/daemons > /dev/null <<EOF
zebra=yes
bgpd=yes
ospfd=yes
ospf6d=yes
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
EOF

# Create a new FRR configuration file
sudo tee /etc/frr/frr.conf > /dev/null <<EOF
!
frr version 7.5
frr defaults traditional
hostname frtr.mrbhardw.awsps.myinstance.com
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
ip route 172.16.0.10/32 blackhole
ip prefix-list PL_PERMIT_1 permit 172.16.0.10/32
!
router bgp ${local_as}
 bgp router-id ${router_id}
 neighbor ${primary_bgp_neighbour} update-source ens5
 neighbor ${primary_bgp_neighbour} remote-as ${remote_as}
 neighbor ${primary_bgp_neighbour} timers 60 180

 neighbor ${secondary_bgp_neighbour} remote-as ${remote_as}
 neighbor ${secondary_bgp_neighbour} update-source ens5
 neighbor ${secondary_bgp_neighbour} timers 60 180

 !
 address-family ipv4 unicast
  network ${bgp_advertised_network}
  neighbor ${primary_bgp_neighbour} route-map RM_HIGHER_LP_200 in
  neighbor ${primary_bgp_neighbour} route-map RM_AS_DEFAULT_1 out
  neighbor ${primary_bgp_neighbour} activate
  neighbor ${secondary_bgp_neighbour}  route-map RM_AS_PREPEND_3 out
  neighbor ${secondary_bgp_neighbour}  route-map RM_DEFAULT_LP_100 in
  neighbor ${secondary_bgp_neighbour} activate
 exit-address-family
!
route-map RM_HIGHER_LP_200 permit 10
 set local-preference 200
!
route-map RM_AS_PREPEND_3 permit 10
match ip address prefix-list PL_PERMIT_1
 set as-path prepend 65001 65001 65001
!

route-map RM_DEFAULT_LP_100 permit 10
 set local-preference 100
!
route-map RM_AS_DEFAULT_1 permit 10
match ip address prefix-list PL_PERMIT_1
set as-path prepend 65001 
!

line vty
!
EOF

# Restart FRR
sudo systemctl restart frr

echo "Installation and configuration completed successfully!"

