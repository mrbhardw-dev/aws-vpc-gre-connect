#!/bin/bash

set -e

# Update and install required packages
apt-get update
apt-get install -y frr curl jq iproute2 net-tools

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure Loopback Interface
echo "Configuring loopback ${loopback_ip}..."
LO_IF="lo:1"
ip link add ${LO_IF} type dummy || true
ip link set ${LO_IF} up
ip addr add ${loopback_ip}/32 dev ${LO_IF}
echo "Loopback ${loopback_ip} configured on ${LO_IF}"

# Configure GRE Tunnel
echo "Configuring GRE Tunnel..."
ip link set dev ens5 mtu 8500
ip tunnel del gre1 2>/dev/null || true
ip tunnel add gre1 mode gre local ${ibgp_gre_local_ip} remote ${ibgp_gre_remote_ip} ttl 255
ip addr add ${ibgp_gre_inside_ip} dev gre1
ip link set gre1 up
echo "GRE Tunnel created between ${ibgp_gre_local_ip} and ${ibgp_gre_remote_ip} with inside IP ${ibgp_gre_inside_ip}"
echo "Configuring GRE Tunnel 2..."
ip tunnel del gre2 2>/dev/null || true
ip tunnel add gre2 mode gre local ${ebgp_gre_local_ip} remote ${ebgp_gre_remote_ip} ttl 255
ip addr add ${ebgp_gre_inside_ip} dev gre2
ip link set gre2 up
echo "GRE2 Tunnel created between ${ebgp_gre_local_ip} and ${ebgp_gre_remote_ip} with inside IP ${ebgp_gre_inside_ip}"

# Configure FRR daemons
cat > /etc/frr/daemons << EOF
zebra=yes
bgpd=yes
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
EOF

# Configure FRR BGP
cat > /etc/frr/frr.conf << EOF
frr version 8.1
frr defaults traditional
hostname router
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!

ip prefix-list LOOPBACK_IP permit ${loopback_ip}/32
!
router bgp ${local_as}
 bgp router-id ${router_id}
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 bgp maximum-paths 2

 neighbor ${ibgp_neighbour} remote-as ${local_as}
 neighbor ${tgw_connect_ebgp_neighbour_1} remote-as ${tgw_remote_as}
 neighbor ${tgw_connect_ebgp_neighbour_1} update-source gre2
 neighbor ${tgw_connect_ebgp_neighbour_1} ebgp-multihop 5
 neighbor ${tgw_connect_ebgp_neighbour_2} remote-as ${tgw_remote_as}
 neighbor ${tgw_connect_ebgp_neighbour_2} update-source gre2
 neighbor ${tgw_connect_ebgp_neighbour_2} ebgp-multihop 5
 !
 address-family ipv4 unicast
  redistribute connected route-map LOOPBACK_ONLY_OUT

  neighbor ${ibgp_neighbour} activate
  neighbor ${ibgp_neighbour} soft-reconfiguration inbound 
  neighbor ${tgw_connect_ebgp_neighbour_1} activate
  neighbor ${tgw_connect_ebgp_neighbour_1} soft-reconfiguration inbound
  neighbor ${tgw_connect_ebgp_neighbour_1} route-map ${primary_route_map} in
  neighbor ${tgw_connect_ebgp_neighbour_1} route-map ${primary_route_map} out
  neighbor ${tgw_connect_ebgp_neighbour_2} activate
  neighbor ${tgw_connect_ebgp_neighbour_2} soft-reconfiguration inbound
  neighbor ${tgw_connect_ebgp_neighbour_2} route-map ${secondary_route_map} in
  neighbor ${tgw_connect_ebgp_neighbour_2} route-map ${secondary_route_map} out
 exit-address-family
!
route-map LOOPBACK_ONLY_OUT permit 10
 match ip address prefix-list LOOPBACK_IP
!
route-map PREFER_MED_10 permit 10
set metric 10
!
route-map PREFER_MED_20 permit 10
 set metric 20
!
EOF

# Restart FRR
systemctl restart frr

echo "GRE, Loopback, and BGP configuration completed" > /var/log/bgp_setup.log
