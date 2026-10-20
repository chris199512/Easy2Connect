#!/bin/bash
#
# Easy2Connect Build Script
# Version 1.3
# by chris199512
# Support : https://forum.feste-ip.net
#
# 05.10.2017 - Easy-RSA
# 23.06.2017 - Debian Strech
# 03.08.2020 - Debian Buster
# 20.10.2026 - Debian Trixie and Easy-RSA 3
#

clear

function rebooter()
{
rm -f /tmp/no_reboot >> /dev/null
echo "Das Easy2Connect System testet beim Systemstart ob eine Internetverbindung besteht."
echo "Wenn nach 10 Minuten immernoch keine aktive Verbindung besteht wird das System neu gestartet."
echo "Sollten Sie dies nicht wuenschen koennen Sie diese Option jetzt deaktivieren."
echo "System ohne aktive Internetverbindung nach 10 Minuten neu starten:"
while true; do
    read -p "(J)a | (N)ein : " yn
    case $yn in
        [Nn]* ) touch /tmp/no_reboot;break;;
        [Jj]* ) break;;
        * ) echo "Unbekannte Auswahl";;
    esac
done
}


function sysprep()
{
date=`date +%s`

export DEBIAN_FRONTEND=noninteractive

if [ -f /etc/modules ] && grep -q ipv6 /etc/modules ; then
 echo "IPv6 Modul bereits vorhanden."
else
 echo "IPv6 Modul nicht geladen. In /etc/modules eingetragen."
 echo ipv6 >> /etc/modules
fi

# Benoetigte Pakete installieren - alle in der aktuellen, von Debian gepflegten Version
apt-get update
apt-get install -y openssl curl gnupg openvpn zip knockd dnsutils psmisc iptables easy-rsa

mv /etc/openvpn /etc/openvpn_orig$date
mkdir /etc/openvpn
# nicht mehr - mount loop ln -s /tmp/easy2connect/openvpn /etc/openvpn
cat << 'EOF' > /etc/knockd.conf
[options]
        UseSyslog

[easyconnectupd]
        sequence    = 12634,26374,982
        seq_timeout = 5
        command     = /bin/easy2connectrefresh
        tcpflags    = syn

[easyconnectreboot]
        sequence    = 2391,1099,43002
        seq_timeout = 5
        command     = /sbin/reboot
        tcpflags    = syn
EOF

# Debian-Paket startet knockd per Default nicht (START_KNOCKD=0)
if [ -f /etc/default/knockd ]; then
 sed -i 's/^START_KNOCKD=0/START_KNOCKD=1/' /etc/default/knockd
fi
if command -v systemctl >> /dev/null 2>&1 ; then
 systemctl enable --now knockd 2>/dev/null
fi

cat << 'EOF' > /bin/easy2connectrefresh
#!/bin/bash
/usr/bin/killall easy2connect
sleep 1
/bin/easy2connect &
EOF

if [ -a /etc/rc.local ]
then
grep -v easy2connect /etc/rc.local > /tmp/rc.local.tmp
grep -v "exit 0" /tmp/rc.local.tmp > /etc/rc.local
cat << 'EOF' >> /etc/rc.local
sleep 10 && nohup /bin/easy2connect > /dev/null &
exit 0
EOF
else
cat << 'EOF' >> /etc/rc.local
#!/bin/sh
sleep 10 && nohup /bin/easy2connect > /dev/null &
exit 0
EOF
chmod 777 /etc/rc.local
fi

cat << 'EOF' > /bin/easy2connect
#!/bin/bash

ALIVE=`/usr/bin/dig +short txt alive.ec.feste-ip.net`
i=1
while [ "$ALIVE" != "\"12345678\"" ]
do
echo $ALIVE
ALIVE=`/usr/bin/dig +short txt alive.ec.feste-ip.net`
sleep 30
i=`expr $i + 1`
if [ $i -gt 20 ]
then
    if [ -a /etc/fipbox/no_reboot ]
    then
    i=1
    else
    /sbin/reboot
    fi
fi
done

if [ `/bin/date +%s` -le 1445871860 ]
then
sudo /bin/date -s @1445871860
fi

killall openvpn 2>/dev/null
while [ `ps ax | grep sbin/openvpn | grep -v grep  | wc -l` != 0 ]
do
sleep 1
echo openvpn......
done

if [ -d /sys/class/leds/led0 ]
then
echo "heartbeat" >/sys/class/leds/led0/trigger
echo "heartbeat" >/sys/class/leds/led1/trigger
fi

cp -r /etc/fipbox /tmp
umount -l /etc/openvpn 2>/dev/null
#MYKEY=`gpg --homedir=/tmp/fipbox --list-key | cut -d "/" -f 2 | cut -d " " -f 1 | head -n 3 | tail -n 1 | awk -F "" {'print $1$2"-"$3$4"-"$5$6"-"$7$8'}`
MYKEY=`gpg --homedir=/tmp/fipbox --list-key --with-colons --no-permission-warning | grep "pub:u" | awk -F ":" '{print $5}' | cut -c9-16 | awk -F "" {'print $1$2"-"$3$4"-"$5$6"-"$7$8'}`
MYKEY2=`echo $MYKEY | awk -F "-" '{print $1$2$3$4}'`
MYKEY2=`echo $((16#$MYKEY2))`
echo $MYKEY | gpg --no-permission-warning --homedir=/tmp/fipbox  --yes --output /tmp/send --sign --encrypt -r easy2connect@feste-ip.net
rm -f /tmp/response
rm -rf /tmp/easy2connect
rm -f /tmp/easy2connect.tgz
curl https://ec.feste-ip.net/ec/ --key /tmp/fipbox/easy2connect.key --cert /tmp/fipbox/easy2connect.crt --cacert /tmp/fipbox/ca.crt --form request=@/tmp/send -F "ver=$(cat /etc/issue)" -F "openvpn=$(openvpn --version |head -n 1)" -o /tmp/response
gpg --no-permission-warning --homedir=/tmp/fipbox --output /tmp/easy2connect.tgz --decrypt /tmp/response
cd /tmp/
tar xzf easy2connect.tgz 2>/dev/null
chmod 777 /tmp/easy2connect/run.sh
mount -o bind /tmp/easy2connect/openvpn/ /etc/openvpn/
/tmp/easy2connect/run.sh &

sleep 65
BASETIME=`/usr/bin/dig +short txt $MYKEY2.ec.feste-ip.net | awk -F "\"" '{print $2}'`
BASETIMECUR=$BASETIME
BASETIME=`expr $BASETIMECUR + 1`
while [ $BASETIME -gt $BASETIMECUR ]
do
sleep 605
BASETIMECUR=`/usr/bin/dig +short txt $MYKEY2.ec.feste-ip.net | awk -F "\"" '{print $2}'`
done
/sbin/reboot
EOF

chmod 777 /bin/easy2connect
chmod 777 /bin/easy2connectrefresh
date=`date +%s`
[ -d /etc/fipbox ] && mv /etc/fipbox /etc/fipbox_$date
}

function new_box()
{
echo " "
rebooter
sysprep
mkdir /etc/fipbox
cp /tmp/no_reboot /etc/fipbox/
clear
echo "E2C ID wird angefordert ... ";
curl -q https://members.feste-ip.net/e2cbuilder/?TASK=NEW -c /tmp/cookie -o /tmp/e2cbuild.tgz
cd /etc/fipbox/
chmod 600 /etc/fipbox
tar xzf /tmp/e2cbuild.tgz
rm /tmp/e2cbuild.tgz
curl -q https://members.feste-ip.net/e2cbuilder/?TASK=NEW -b /tmp/cookie
}

function known_box()
{
echo " "
rebooter
sysprep
clear
echo "Fuer die Installation einer bestehen E2C Box benoetigen wir die E2C ID sowie den Installationscode. ";
echo "Bitte geben Sie diese Daten jetzt ein!"
echo " "
read -p "Easy2Connect-ID   : " e2cid
read -p "Installationscode : " installcode
echo " "
while true; do
    read -p "E2CID $e2cid - INSTALLCODE $installcode korrekt ? (J)a | (N)ein : " yn
    case $yn in
        [Nn]* ) exit;;
        [Jj]* ) break;;
        * ) echo "Unbekannte Auswahl";;
    esac
done
echo "Die Daten werden abgerufen ..."
curl https://members.feste-ip.net/e2cbuilder/?TASK=KNOWN --data "e2cid=$e2cid&installcode=$installcode" -o /tmp/e2cbuild.tgz
if [ `ls -l /tmp/e2cbuild.tgz | tr -s " " | cut -d " " -f 5` -lt 1000 ]; then
echo " "
cat /tmp/e2cbuild.tgz
echo "Beim Abruf der Daten ist ein Fehler aufgetreten."
echo "Bitte pruefen Sie die eingegebenen Daten oder wenden Sie sich an unseren Support."
echo " "
exit
else
mkdir /etc/fipbox
cp /tmp/no_reboot /etc/fipbox/
clear
cd /etc/fipbox/
chmod 600 /etc/fipbox
tar xzf /tmp/e2cbuild.tgz
rm /tmp/e2cbuild.tgz
echo "Die Daten wurden abgerufen. Bitte starten Sie das System jetzt neu!"
fi
}



# Test apt-get
apt-get --help > /dev/null
if [ `echo $?` -gt 0 ]; then
echo .
echo Kein apt-get basierter Installer gefunden !!!
echo .
exit
fi


if [ `id -u` -gt 0 ]; then
echo .
echo Nicht genuegend Systemrechte !!
echo .
exit
fi


if [ -d "/etc/fipbox" ]; then
echo .
echo bestehende Installation "(/etc/fipbox)" gefunden!
echo .
exit
fi

cat << 'EOF'
                       _____                                 _
                      / __  \               Installer V 1.3 | |
  ___  __ _ ___ _   _ `' / /' ___ ___  _ __  _ __   ___  ___| |_
 / _ \/ _` / __| | | |  / /  / __/ _ \| '_ \| '_ \ / _ \/ __| __|
|  __/ (_| \__ \ |_| |./ /__| (_| (_) | | | | | | |  __/ (__| |_
 \___|\__,_|___/\__, |\_____/\___\___/|_| |_|_| |_|\___|\___|\__|
                 __/ |
                |___/                     by chris199512
EOF
echo " "
echo " "
echo -E "Mit diesem Installer wird die 'easy2connect' Funktion von feste-ip.net
auf ihrem System installiert. Trotz intensiver Tests koennen wir fuer
die Funktion sowie Aus / Nebenwirkungen auf 'Fremdsystemen' keine
Garantie / Haftung uebernehmen."
echo " "
echo "Bitte erstellen Sie auf jeden Fall eine Sicherung !!!"
echo " "
echo "Installationsmodus waehlen:"
while true; do
    read -p "(N)eue Box | (B)estehende Box-ID verwenden | (A)bbrechen: " yn
    case $yn in
        [Nn]* ) new_box;exit;;
        [Bb]* ) known_box;exit;;
        [Aa]* ) exit;;
        * ) echo "Unbekannte Auswahl";;
    esac
done
