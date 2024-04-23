#!/bin/bash

ipset create PROXY_SET hash:net timeout 604800

# prepare dnsmasq config
source_file="/root/dns.custom.conf"
target_file="/run/dnsmasq.conf.d/dns.custom.conf"

# copy dnsmasq set list
source_md5=$(md5sum "$source_file" | awk '{print $1}')
target_md5=$(md5sum "$target_file" | awk '{print $1}')
# 检查 MD5 值是否相同
if [ "$source_md5" != "$target_md5" ]; then
    # 如果不同，则复制源文件到目标文件
    cp "$source_file" "$target_file"
    killall dnsmasq
    echo "dns.custom.conf file copy because MD5 values are changed."
else
    echo 'no new dns.custom.conf diff found.'
fi

# prepare iptables config
if [ "$(iptables -t mangle -L AUTO_VPN | wc -l)" = 0 ] ; then
    iptables -t mangle -N AUTO_VPN
    iptables -t mangle -A AUTO_VPN -m set --match-set PROXY_SET dst -j MARK --set-xmark 0x800000/0x7f800000
    iptables -t mangle -A AUTO_VPN -j ACCEPT
    iptables -t mangle -A AUTO_VPN -j RETURN
else
   echo 'iptables mangle is ok.'
fi

# prepare ip route rules
if ! ip route show table proxy_table; then
  echo preparing ip route
  echo '100    proxy_table' >> /etc/iproute2/rt_table
  ip route add default via 10.0.0.3 dev br0 table proxy_table
  ip rule add fwmark 0x800000/0x7f800000 lookup proxy_table
else
  echo 'ip proxy table ok.'
fi
