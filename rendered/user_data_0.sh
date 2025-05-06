#!/bin/bash

set -e

# Update and install required packages
apt-get update
apt-get install -y frr curl jq iproute2 net-tools traceroute mtr

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure Loopback Interface
echo "Configuring loopback 172.16.0.10..."
LO_IF="lo:1"
ip link add lo:1 type dummy || true
ip link set lo:1 up
ip addr add 172.16.0.10/32 dev lo:1
echo "Loopback 172.16.0.10 configured on lo:1"

# Configure GRE Tunnel
echo "Configuring GRE Tunnel..."
ip link set dev ens5 mtu 8500
ip tunnel del gre1 2>/dev/null || true
ip tunnel add gre1 mode gre local 100.64.2.100 remote 100.64.3.100 ttl 255
ip addr add 169.254.6.1/29 dev gre1
ip link set gre1 up
echo "GRE Tunnel created between 100.64.2.100 and 100.64.3.100 with inside IP 169.254.6.1/29"
echo "Configuring GRE Tunnel 2..."
ip tunnel del gre2 2>/dev/null || true
ip tunnel add gre2 mode gre local 100.64.2.100 remote 192.168.0.10 ttl 255
ip addr add 169.254.200.1/29 dev gre2
ip link set gre2 up
echo "GRE2 Tunnel created between 100.64.2.100 and 192.168.0.10 with inside IP 169.254.200.1/29"

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

ip prefix-list LOOPBACK_IP permit 172.16.0.10/32
!
router bgp 65001
 bgp router-id 100.64.2.100
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 bgp maximum-paths 2
 neighbor 100.64.2.89 remote-as 64512
 neighbor 100.64.2.89 update-source ens5
 neighbor 100.64.2.89 ebgp-multihop 5
 neighbor 169.254.6.2 remote-as 65001
 neighbor 169.254.200.2 remote-as 64532
 neighbor 169.254.200.2 update-source gre2
 neighbor 169.254.200.2 ebgp-multihop 5
 neighbor 169.254.200.3 remote-as 64532
 neighbor 169.254.200.3 update-source gre2
 neighbor 169.254.200.3 ebgp-multihop 5
 !
 address-family ipv4 unicast
  redistribute connected route-map LOOPBACK_ONLY_OUT
  neighbor 100.64.2.89 activate
  neighbor 100.64.2.89 soft-reconfiguration inbound 
  neighbor 100.64.2.89 route-map PREFER_MED_10 out
  neighbor 100.64.2.89 route-map PREFER_MED_10 in
  neighbor 169.254.6.2 activate
  neighbor 169.254.6.2 soft-reconfiguration inbound 
  neighbor 169.254.200.2 activate
  neighbor 169.254.200.2 soft-reconfiguration inbound
  neighbor 169.254.200.2 route-map PREFER_MED_10 in
  neighbor 169.254.200.2 route-map PREFER_MED_10 out
  neighbor 169.254.200.3 activate
  neighbor 169.254.200.3 soft-reconfiguration inbound
  neighbor 169.254.200.3 route-map PREFER_MED_20 in
  neighbor 169.254.200.3 route-map PREFER_MED_20 out
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
