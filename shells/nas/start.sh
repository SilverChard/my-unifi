#!/bin/bash

ss_server=120.204.94.47
local_port=1080

# Clear iptables
iptables -F
iptables -X
iptables -Z

iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z

iptables -t mangle -F
iptables -t mangle -X
iptables -t mangle -Z

# Create new chain
iptables -t nat -N SS_PROXY
iptables -t mangle -N SS_PROXY

# Ignore your SS_PROXY server's addresses
# It's very IMPORTANT, just be careful.
iptables -t nat -A SS_PROXY -d $ss_server -j RETURN

# Ignore LANs and any other addresses you'd like to bypass the proxy
# See Wikipedia and RFC5735 for full list of reserved networks.
# See ashi009/bestroutetb for a highly optimized CHN route list.
iptables -t nat -A SS_PROXY -d 0.0.0.0/8 -j RETURN
iptables -t nat -A SS_PROXY -d 10.0.0.0/8 -j RETURN
iptables -t nat -A SS_PROXY -d 127.0.0.0/8 -j RETURN
iptables -t nat -A SS_PROXY -d 169.254.0.0/16 -j RETURN
iptables -t nat -A SS_PROXY -d 172.16.0.0/12 -j RETURN
iptables -t nat -A SS_PROXY -d 192.168.0.0/16 -j RETURN
iptables -t nat -A SS_PROXY -d 224.0.0.0/4 -j RETURN
iptables -t nat -A SS_PROXY -d 240.0.0.0/4 -j RETURN


# Anything else should be redirected to SS_PROXY's local port
iptables -t nat -A SS_PROXY -p tcp -j REDIRECT --to-ports $local_port

# UDP
if ! ip rule show | grep -q 'fwmark 0x2/0x2 lookup 100'; then
  ip rule add fwmark 0x02/0x02 table 100
else 
  echo "路由 fwmark 0x02/0x02 table 100 已存在，无需添加。"
fi
if ! ip route show table 100; then
  # 如果路由不存在，则添加路由
  ip route add local 0.0.0.0/0 dev lo table 100
else
  echo "路由 0.0.0.0/0 dev lo table 100 已存在，无需添加。"
fi

iptables -t mangle -A SS_PROXY -d $ss_server -j RETURN
iptables -t mangle -A SS_PROXY -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A SS_PROXY -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A SS_PROXY -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A SS_PROXY -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A SS_PROXY -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A SS_PROXY -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A SS_PROXY -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A SS_PROXY -d 240.0.0.0/4 -j RETURN
# Redirect UDP
iptables -t mangle -A SS_PROXY -p udp -j TPROXY --on-port $local_port --tproxy-mark 0x02/0x02


# Apply the rules
iptables -t nat -A PREROUTING -p tcp -j SS_PROXY
iptables -t mangle -A PREROUTING -j SS_PROXY

if [ "$(cat /proc/sys/net/ipv4/ip_forward)" == "0" ] ; then
  echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
  sysctl -p
else
  echo ip forward is ok ;
fi

# Start the SS_PROXY-redir
ss-redir -c /root/config.json -u -v -f /root/ss-redir.pid
