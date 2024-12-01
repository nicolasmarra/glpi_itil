#!/bin/sh

iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.56.0/24 -j MASQUERADE  
iptables -t nat -A POSTROUTING -s 192.168.57.0/24 -j MASQUERADE  

echo 1 > /proc/sys/net/ipv4/ip_forward

