#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of Network Config checks.
#--------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

NWCHECK1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2 |cut -d " " -f2)
IPV4_FORWARD_CHECK="Fail"
if [ "$NWCHECK1" = 0 ]; then IPV4_FORWARD_CHECK="Pass"; fi

NWCHECK2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2 |cut -d " " -f2)
IPV4_ALL_SEND_REDIRECTS="Fail"
if [ "$NWCHECK2" = 0 ]; then IPV4_ALL_SEND_REDIRECTS="Pass"; fi

NWCHECK3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
IPV4_ALL_ACCEPT_SOURCE_ROUTE="Fail"
if [ "$NWCHECK3" = 0 ]; then IPV4_ALL_ACCEPT_SOURCE_ROUTE="Pass"; fi

NWCHECK4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Fail"
if [ "$NWCHECK4" = 0 ]; then IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Pass"; fi

NWCHECK5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
IPV4_ALL_ACCEPT_REDIRECTS="Fail"
if [ "$NWCHECK5" = 0 ]; then IPV4_ALL_ACCEPT_REDIRECTS="Pass"; fi

NWCHECK6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
IPV4_DEFAULT_ACCEPT_REDIRECTS="Fail"
if [ "$NWCHECK6" = 0 ]; then IPV4_DEFAULT_ACCEPT_REDIRECTS="Pass"; fi

NWCHECK7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
IPV4_ALL_SECURE_REDIRECTS="Fail"
if [ "$NWCHECK7" = 0 ]; then IPV4_ALL_SECURE_REDIRECTS="Pass"; fi

NWCHECK8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
IPV4_DEFAULT_SECURE_REDIRECTS="Fail"
if [ "$NWCHECK8" = 0 ]; then IPV4_DEFAULT_SECURE_REDIRECTS="Pass"; fi

NWCHECK9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2 |cut -d " " -f2)
ICMP_IGNORE_BROADCASTS="Fail"
if [ "$NWCHECK9" = 1 ]; then ICMP_IGNORE_BROADCASTS="Pass"; fi

NWCHECK10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2 |cut -d " " -f2)
ICMP_IGNORE_BOGUS_ERROR="Fail"
if [ "$NWCHECK10" = 1 ]; then ICMP_IGNORE_BOGUS_ERROR="Pass"; fi

NWCHECK11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2 |cut -d " " -f2)
ALL_RP_FILTER="Fail"
if [ "$NWCHECK11" = 1 ]; then ALL_RP_FILTER="Pass"; fi

NWCHECK12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2 |cut -d " " -f2)
TCP_SYNCOOKIES="Fail"
if [ "$NWCHECK12" = 1 ]; then TCP_SYNCOOKIES="Pass"; fi

NWCHECK13=$(sysctl net.ipv6.conf.all.disable_ipv6 |cut -d "=" -f2 |cut -d " " -f2)
DISABLE_IPV6="Fail"
if [ "$NWCHECK13" = 1 ]; then DISABLE_IPV6="Pass"; fi

NWCHECK14=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2 |cut -d " " -f2)
IPV6_ALL_ACCEPT_RA="Fail"
if [ "$NWCHECK14" = 1 ]; then IPV6_ALL_ACCEPT_RA="Pass"; fi


cat > $RDIR/$HOST_NAME-nwconfigreport.md<< EOF

---
title: Network Configuration Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

IPv4 IP Forward Check :
 ~ $IPV4_FORWARD_CHECK

IPv4 All Send Redirects Check :
 ~ $IPV4_ALL_SEND_REDIRECTS

IPv4 All Accept Source Route Check :
 ~ $IPV4_ALL_ACCEPT_SOURCE_ROUTE

IPv4 Default Accept Source Route Check :
 ~ $IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE

IPv4 All Accept Redirects Check :
 ~ $IPV4_ALL_ACCEPT_REDIRECTS

IPv4 Default Accept Redirects Check :
 ~ $IPV4_DEFAULT_ACCEPT_REDIRECTS

IPv4 All Secure Redirects Check :
 ~ $IPV4_ALL_SECURE_REDIRECTS

IPv4 Default Secure Redirects Check :
 ~ $IPV4_DEFAULT_SECURE_REDIRECTS

IPv4 ICMP Echo Ignore Broadcasts Check :
 ~ $ICMP_IGNORE_BROADCASTS

IPv4 ICMP Ignore Bogus Error Resp. Check :
 ~ $ICMP_IGNORE_BOGUS_ERROR

IPv4 ALL RP Filter Check :
 ~ $ALL_RP_FILTER

IPV4 TCP SynCookies Check :
 ~ $TCP_SYNCOOKIES

IPv6 Disable IPv6 Check :
 ~ $DISABLE_IPV6

IPv6 All Accept Ra Check :
 ~ $IPV6_ALL_ACCEPT_RA

---
EOF

cat > $RDIR/$HOST_NAME-nwconfigreport.txt << EOF
====================================================================================================
:::. $HOST_NAME NETWORK CONFIG INFORMATION REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
Network Settings
----------------------------------------------------------------------------------------------------
IPv4 IP Forward Check                    | $IPV4_FORWARD_CHECK
IPv4 All Send Redirects Check            | $IPV4_ALL_SEND_REDIRECTS
IPv4 All Accept Source Route Check       | $IPV4_ALL_ACCEPT_SOURCE_ROUTE
IPv4 Default Accept Source Route Check   | $IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE
IPv4 All Accept Redirects Check          | $IPV4_ALL_ACCEPT_REDIRECTS
IPv4 Default Accept Redirects Check      | $IPV4_DEFAULT_ACCEPT_REDIRECTS
IPv4 All Secure Redirects Check          | $IPV4_ALL_SECURE_REDIRECTS
IPv4 Default Secure Redirects Check      | $IPV4_DEFAULT_SECURE_REDIRECTS
IPv4 ICMP Echo Ignore Broadcasts Check   | $ICMP_IGNORE_BROADCASTS
IPv4 ICMP Ignore Bogus Error Resp. Check | $ICMP_IGNORE_BOGUS_ERROR
IPv4 ALL RP Filter Check                 | $ALL_RP_FILTER
IPV4 TCP SynCookies Check                | $TCP_SYNCOOKIES
IPv6 Disable IPv6 Check                  | $DISABLE_IPV6
IPv6 All Accept Ra Check                 | $IPV6_ALL_ACCEPT_RA
====================================================================================================
EOF
