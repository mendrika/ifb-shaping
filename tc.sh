#!/bin/sh -x

# Maximum allowed downlink. Set to 90% of the achievable downlink in kbits/s
DOWNLINK=1000

# Interface facing the Internet
EXTDEV=wlp1s0

# Load IFB, all other modules all loaded automatically
modprobe ifb
ip link set dev ifb0 down 2> /dev/null > /dev/null
ip link del ifb0
# Clear old queuing disciplines (qdisc) on the interfaces and the MANGLE table
tc qdisc del dev $EXTDEV root    2> /dev/null > /dev/null
tc qdisc del dev $EXTDEV ingress 2> /dev/null > /dev/null
tc qdisc del dev ifb0 root       2> /dev/null > /dev/null
tc qdisc del dev ifb0 ingress    2> /dev/null > /dev/null


# appending "stop" (without quotes) after the name of the script stops here.
if [ "$1" = "stop" ]
then
        echo "Shaping removed on $EXTDEV."
        exit
fi
ip link add ifb0 type ifb
ip link set dev ifb0 up

# HTB classes on IFB with rate limiting
tc qdisc add dev ifb0 root handle 1: htb default 20
tc class add dev ifb0 parent 1: classid 1:10 htb rate ${DOWNLINK}kbps
tc class add dev ifb0 parent 1: classid 1:20 htb rate 400kbps ceil ${DOWNLINK}kbps
tc class add dev ifb0 parent 1: classid 1:30 htb rate 140kbps ceil ${DOWNLINK}kbps
	
# Forward all ingress traffic on internet interface to the IFB device
tc qdisc add dev $EXTDEV ingress handle ffff:
tc filter add dev $EXTDEV parent ffff: protocol ip \
        u32 match u32 0 0 \
        action connmark \
        action mirred egress redirect dev ifb0 \
        flowid ffff:1

exit 0

