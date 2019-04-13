#!/usr/bin/env bash

SPIP=''

SITE1='www.cloudflare.com'
SITE2='www.google.com'
DNS1='8.8.8.8'
DNS2='1.1.1.1'

PINGS='10'
SLEEPTIME='600'

LOGFILE="/var/log/amionline.log"

ROUND='0'
#CHECK='0'
PINGCHECK_STANDARDMAXLOSS='10'
PINGCHECK_CHECKMAXLOSS='0'

####################################################
# Checks
####################################################

pingcheck1(){
        pingcheck1text="$(ping -c "$PINGS" "$SITE1" -q 2>&1)"
        pingcheck1text_received=$(echo "$pingcheck1text" | sed -n -e 's/^.*transmitted, //p' | cut -d ' ' -f1)
        pingcheck1text_loss=$(echo "$pingcheck1text" | sed -n -e 's/^.*received, //p' | cut -d % -f1)
        pingcheck1text_metric=$(echo "$pingcheck1text" | sed -n -e 's/^.*rtt //p')
        if [ -z "$pingcheck1text_received" ]; then
                echo -n " - $pingcheck1text" >> "$LOGFILE"
                pingcheck1error=true
        elif [ "$pingcheck1text_loss" -gt "$PINGCHECK_STANDARDMAXLOSS" ]; then
                echo -n " - SITE1 too much loss ($SITE1 - S/R/L%:$PINGS/$pingcheck1text_received/$pingcheck1text_loss%) - ($pingcheck1text_metric)" >> "$LOGFILE"
                pingcheck1error=true
        else
                echo -n " - ($SITE1 - S/R/L%:$PINGS/$pingcheck1text_received/$pingcheck1text_loss%) - ($pingcheck1text_metric)" >> "$LOGFILE"
        fi
}
pingcheck2(){
        pingcheck2text="$(ping -c "$PINGS" "$SITE2" -q 2>&1)"
        pingcheck2text_received=$(echo "$pingcheck2text" | sed -n -e 's/^.*transmitted, //p' | cut -d ' ' -f1)
        pingcheck2text_loss=$(echo "$pingcheck2text" | sed -n -e 's/^.*received, //p' | cut -d % -f1)
        pingcheck2text_metric=$(echo "$pingcheck2text" | sed -n -e 's/^.*rtt //p')
        if [ -z "$pingcheck2text_received" ]; then
                echo -n " - $pingcheck2text" >> "$LOGFILE"
                pingcheck2error=true
        elif [ "$pingcheck2text_loss" -gt "$PINGCHECK_CHECKMAXLOSS" ]; then
                echo -n " - SITE2 too much loss ($SITE2 - S/R/L%:$PINGS/$pingcheck2text_received/$pingcheck2text_loss%) - ($pingcheck2text_metric)" >> "$LOGFILE"
                pingcheck2error=true
        else
                echo -n " - ($SITE2 - S/R/L%:$PINGS/$pingcheck1text_received/$pingcheck1text_loss%) - ($pingcheck2text_metric)" >> "$LOGFILE"
        fi
}
dnscheck1(){
        if ! nslookup1="$(nslookup "$SITE1" "$DNS1" 2>&1)"; then
                echo -n " - DNS1 Problem ($SITE1 on $DNS1)" >> "$LOGFILE"
                dnscheck1error=true
        fi
}
dnscheck2(){
        if ! nslookup2="$(nslookup "$SITE2" "$DNS2" 2>&1)"; then
                echo -n " - DNS1 Problem ($SITE2 on $DNS2)" >> "$LOGFILE"
                dnscheck2error=true
        fi
}
extracheck(){
        pingcheck2
        dnscheck2
        if [[ -z "$pingcheck2error" && -z "$dnscheck2error" ]]; then
                STATUS='0'
        else
                STATUS='1'
        fi
}

####################################################
# Work
####################################################

echo -e "\n\n\n" >> $LOGFILE

while true
do
        echo -n "$(date)" >> $LOGFILE
        pingcheck1
        dnscheck1
    if [[ -z "$pingcheck1error" && -z "$dnscheck1error" ]]; then
                STATUS='0'
        else
                extracheck
        fi

####################################################
# Evaluation
####################################################

    if [ "$STATUS" -ne "0" ]
    then
        ROUND=$((ROUND + 1))
        echo -n " || ROUND $ROUND FAILED" >> $LOGFILE
    else
        ROUND='0'
        echo -n " || CHECK OK" >> $LOGFILE
    fi

    if [ "$ROUND" -ge "2" ]
    then
        ROUND='0'
        echo -n " || CUT POWER" >> $LOGFILE
		./hs100/hs100.sh -i "$SPIP" off
		sleep "10"
		./hs100/hs100.sh -i "$SPIP" on
    fi
    echo "" >> $LOGFILE
    unset pingcheck1error
    unset pingcheck2error
    unset dnscheck1error
    unset dnscheck2error
    sleep $SLEEPTIME
done