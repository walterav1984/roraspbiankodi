#!/bin/bash

#
# rrk.sh roraspbiankodi
#
ACTIONIS=$1

function firstbootupgrades {
sudo apt-get update
sudo apt-get -y upgrade 
sudo apt-get -y dist-upgrade
}

function performancetweaks {
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
head -n 19 /etc/rc.local | sudo tee /etc/rc.local
echo "sudo echo \"performance\" | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" | sudo tee -a /etc/rc.local
echo "exit 0" | sudo tee -a /etc/rc.local
sudo systemctl stop triggerhappy #timer or service or socket?
sudo systemctl disable triggerhappy
sudo systemctl stop apt-daily.timer
sudo systemctl disable apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.timer

#disable ipv6
sudo sed -i "s/wait/wait ipv6.disable=1 usbcore.autosuspend=-1 usbcore.autosuspend_delay_ms=0/g" /boot/cmdline.txt
sudo tee /etc/modprobe.d/ipv6.conf <<_EOF_ 
alias net-pf-10 off
options ipv6 disable_ipv6=1
blacklist ipv6
_EOF_


#set gpu/cpu memory split
sudo tee -a /boot/config.txt <<_EOF_
#start_x=1
gpu_mem_256=112
gpu_mem_512=160
gpu_mem_1024=256

#1080p50
disable_overscan=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=31
#hdmi_pixel_encoding=0

#uncomment following single line for enabling single IR receiver
#dtoverlay=gpio-ir

#uncomment following 3 lines for PiFi DAC+ v2.0 with builtin IR receiver
#dtparam=i2s=on
#dtoverlay=hifiberry-dacplus
#dtoverlay=gpio-ir,gpio_pin=26
_EOF_
#vcgencmd get_mem arm && vcgencmd get_mem gpu #check memory split

#cron reschedule to midnight
sudo sed -i "s/17 \*/17 3/g" /etc/crontab
sudo sed -i "s/25 6/25 3/g" /etc/crontab
sudo sed -i "s/47 6/47 3/g" /etc/crontab
sudo sed -i "s/52 6/52 3/g" /etc/crontab
}

function setlocaldefaults {
sudo sed -i "s/gb/us/g" /etc/default/keyboard
sudo timedatectl set-timezone Europe/Amsterdam
#timedate-ctl list-timezones
}

function extraconfigs {
#/boot partition config files for overiding readonly system and kodi behaviour 
sudo mkdir /boot/settings

sudo tee -a /boot/settings/HTSCONF.txt <<_EOF_
#TVHeadend Credentials uncomment&edit HTSNFSF for nfsshare folder on HTSSERV 
HTSUSER=exampleuser
HTSPASS=examplepass
HTSSERV=exampleipaddress
HTSWOLM=examplemacaddress
HTSHTTP=9981
HTSHTSP=9982
#HTSNFSF=/mnt/sdb1/tvherecordings
_EOF_

sudo tee -a /boot/settings/PVRTYPE.txt <<_EOF_
#Uncomment only a single kodi PVR frontend: 'tvheadend' is default
tvheadend
#hdhomerun
#itsclient
_EOF_

sudo tee -a /boot/settings/ISCCONF.txt <<_EOF_
#Uncomment only a single iptvsimpleclient setting: 'remote' or 'loca 'is default
local=/boot/settings/playlist.m3u
#remote=http://example.io/atom.m3u
_EOF_

sudo tee -a /boot/settings/playlist.m3u <<_EOF_
#EXTM3U

#EXTINF:-1 channelname01
http://null.example.m3u8

#EXTINF:-1,channelname02
rtmp://null.example
_EOF_

sudo tee -a /boot/settings/AUDIOout.txt <<_EOF_
#Uncomment only a single audio output as in: HDMI, Analogue, Both, DAC, HDMIPASS
#Note that hdmi dolbydigital/dts passthrough won't work with pvr-live tv in 17.x
HDMI
#Analogue
#Both
#DAC
#HDMIPASS
_EOF_

sudo tee -a /boot/settings/WIFI.txt <<_EOF_
#Just complete '/boot/wpa_supplicant.conf' with the following example code below
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=UK

network={
	ssid="example"
	psk="example"
	key_mgmt=WPA-PSK
}

_EOF_

sudo tee -a /boot/wpa_supplicant.conf <<_EOF_
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
_EOF_

#persistent fix wpa_supplicant for readonly behaviour
sudo rm /etc/wpa_supplicant/wpa_supplicant.conf
sudo ln -s /boot/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
sudo systemctl disable raspberrypi-net-mods.service

#persistent allow static ip setup in /boot/settings
sudo cp /etc/dhcpcd.conf /boot/settings/
sudo rm /etc/dhcpcd.conf
sudo ln -s /boot/settings/dhcpcd.conf /etc/dhcpcd.conf

cat <<'_EOF_' > /home/pi/setpvr.sh
#!/bin/bash
#Overwrite Addons27.db database for enforcing a single active kodi PVR frontend
case $(cat /boot/settings/PVRTYPE.txt | grep -v '#') in
	none)
	echo "[  OK  ] setpvr.sh no pvr addon selected"
	cp /home/pi/nonAddons27.db /tmp/kodirw/userdata/Database/Addons27.db
	;;
	tvheadend)
	echo "[  OK  ] setpvr.sh sets tvheadend"
	cp /home/pi/htsAddons27.db /tmp/kodirw/userdata/Database/Addons27.db
    /home/pi/sethts.sh
    /home/pi/setnfs.sh
	;;
	hdhomerun)
	echo "[  OK  ] setpvr.sh sets hdhomerun"
	cp /home/pi/hhrAddons27.db /tmp/kodirw/userdata/Database/Addons27.db
	;;
	itsclient)
	echo "[  OK  ] setpvr.sh sets iptvsimpleclient"
	cp /home/pi/iscAddons27.db /tmp/kodirw/userdata/Database/Addons27.db
    /home/pi/setisc.sh
    ;;
esac
_EOF_
chmod +x /home/pi/setpvr.sh

sudo apt-get -y install wakeonlan
cat <<'_EOF_' > /home/pi/sethts.sh
#!/bin/bash
#Parce /boot/settings for setting up pvr-hts tvheadend frontend
HTSWOLM=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSWOLM | sed -e 's/HTSWOLM=//g' -)
wakeonlan $HTSWOLM
HTSSERV=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSSERV | sed -e 's/HTSSERV=//g' -)
sed -i -e "s/192.168.123.123/$HTSSERV/g" /tmp/kodirw/userdata/addon_data/pvr.hts/settings.xml
HTSUSER=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSUSER | sed -e 's/HTSUSER=//g' -)
sed -i -e "s/htsu/$HTSUSER/g" /tmp/kodirw/userdata/addon_data/pvr.hts/settings.xml
HTSPASS=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSPASS | sed -e 's/HTSPASS=//g' -)
sed -i -e "s/htsw/$HTSPASS/g" /tmp/kodirw/userdata/addon_data/pvr.hts/settings.xml
HTSHTTP=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSHTTP | sed -e 's/HTSHTTP=//g' -)
sed -i -e "s/9981/$HTSHTTP/g" /tmp/kodirw/userdata/addon_data/pvr.hts/settings.xml
HTSHTSP=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSHTSP | sed -e 's/HTSHTSP=//g' -)
sed -i -e "s/9982/$HTSHTSP/g" /tmp/kodirw/userdata/addon_data/pvr.hts/settings.xml
_EOF_
chmod +x /home/pi/sethts.sh

cat <<'_EOF_' > /home/pi/setisc.sh
#!/bin/bash
#Parce /boot/settings for selecting local/remote url for pvr-iptvsimple frontend
case $(cat /boot/settings/ISCCONF.txt | grep -v '#' | sed -e 's/=.*//' -) in
	local)
	echo "[  OK  ] setisc.sh sets iptvsimpleclient local"
    cp /home/pi/kodiro/userdata/addon_data/pvr.iptvsimple/locsettings.xml /tmp/kodirw/userdata/addon_data/pvr.iptvsimple/settings.xml
    REPM3U=$(cat /boot/settings/ISCCONF.txt | grep -v '#' | sed -e 's/.*=//' -)
    sed -i -e "s|replacem3u|$REPM3U|g" /tmp/kodirw/userdata/addon_data/pvr.iptvsimple/settings.xml
	;;
	remote)
	echo "[  OK  ] setisc.sh sets iptvsimpleclient remote"
    cp /home/pi/kodiro/userdata/addon_data/pvr.iptvsimple/remsettings.xml /tmp/kodirw/userdata/addon_data/pvr.iptvsimple/settings.xml
    REPURL=$(cat /boot/settings/ISCCONF.txt | grep -v '#' | sed -e 's/.*=//' -)
    sed -i -e "s|replaceurl|$REPURL|g" /tmp/kodirw/userdata/addon_data/pvr.iptvsimple/settings.xml
	;;
esac
_EOF_
chmod +x /home/pi/setisc.sh

cat <<'_EOF_' > /home/pi/setaudio.sh
#!/bin/bash
#Parce /boot/settings for setting up audio output in kodi
case $(cat /boot/settings/AUDIOout.txt | grep -v '#') in
	HDMI)
	echo "[  OK  ] setaudio.sh sets PI:HDMI"
    #default needs nothing
	;;
	Analogue)
	echo "[  OK  ] setaudio.sh sets PI:Analogue"
	#change guisettings.xml?
    sed -i 's/ default="true">PI:HDMI/>PI:Analogue/g' /tmp/kodirw/userdata/guisettings.xml
	;;
	Both)
	echo "[  OK  ] setaudio.sh sets PI:Both"
	#change guisettings.xml?
    sed -i 's/ default="true">PI:HDMI/>PI:Both/g' /tmp/kodirw/userdata/guisettings.xml
    ;;
	DAC)
	echo "[  OK  ] setaudio.sh sets external DAC"
	#change guisettings.xml ALSA?
    sed -i 's/ default="true">PI:HDMI/>ALSA:@/g' /tmp/kodirw/userdata/guisettings.xml
    cp /home/pi/alsa.conf /tmp/alsa.conf
    sudo sed -i "s/defaults.ctl.card 0/defaults.ctl.card 1/g" /tmp/alsa.conf
    sudo sed -i "s/defaults.pcm.card 0/defaults.pcm.card 1/g" /tmp/alsa.conf
    ;;
	HDMIPASS)
	echo "[  OK  ] setaudio.sh sets PI:HDMI (E)AC3/DTS PASSTHROUGH"
	#change guisettings.xml ALSA?
    sed -i 's|<passthrough default="true">false</passthrough>|<passthrough>true</passthrough>|g' /tmp/kodirw/userdata/guisettings.xml
    sed -i 's|<eac3passthrough default="true">false</eac3passthrough>|<eac3passthrough>true</eac3passthrough>|g' /tmp/kodirw/userdata/guisettings.xml
    sed -i 's|<dtspassthrough default="true">false</dtspassthrough>|<dtspassthrough>true</dtspassthrough>|g' /tmp/kodirw/userdata/guisettings.xml
    ;;
esac
_EOF_
chmod +x /home/pi/setaudio.sh

#persistent audio changes to allow settings by /boot/settings
cp /usr/share/alsa/alsa.conf /home/pi/alsa.conf
sudo rm /usr/share/alsa/alsa.conf
sudo ln -s /tmp/alsa.conf /usr/share/alsa/alsa.conf

cat <<'_EOF_' > /home/pi/setnfs.sh
#!/bin/bash
#Parce /boot/settings for enabling nfsshare based on TVHeadend HTS variables
case $(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSNFSF | sed -e 's/=.*//' -) in
	HTSNFSF)
	echo "[  OK  ] setnfs.sh sets nfsshare active"
    #get nfs server ip
    NFSSERV=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSSERV | sed -e 's/.*=//' -)
    #get nfs server folder
    NFSFOLD=$(cat /boot/settings/HTSCONF.txt | grep -v '#' | grep HTSNFSF | sed -e 's/.*=//' -)
    sudo mkdir /tmp/nfsshare
    sudo mount -t nfs -o proto=tcp $NFSSERV:$NFSFOLD /tmp/nfsshare/
#Create a kodi source for the nfsshare folder
cat <<'_FOE_' > /tmp/kodirw/userdata/sources.xml
<sources>
    <programs>
        <default pathversion="1"></default>
    </programs>
    <video>
        <default pathversion="1"></default>
        <source>
            <name>TVHE-Recordings</name>
            <path pathversion="1">/tmp/nfsshare/</path>
            <allowsharing>false</allowsharing>
        </source>
    </video>
    <music>
        <default pathversion="1"></default>
    </music>
    <pictures>
        <default pathversion="1"></default>
    </pictures>
    <files>
        <default pathversion="1"></default>
    </files>
</sources>
_FOE_
	;;
esac
_EOF_
chmod +x /home/pi/setnfs.sh

}

function installkodi {
sudo apt-get -y install kodi kodi-pvr-hts kodi-pvr-hdhomerun kodi-pvr-iptvsimple kodi-peripheral-joystick kodi-inputstream-adaptive kodi-inputstream-rtmp
#Create a kodi service https://www.raspberrypi.org/forums/viewtopic.php?f=66&t=192499
sudo tee -a /lib/systemd/system/kodi.service <<_EOF_
[Unit]
Description = Kodi Media Center
After = remote-fs.target network-online.target
Wants = network-online.target

[Service]
User = pi
Group = pi
Type = simple
ExecStart = /usr/bin/kodi
Restart = on-abort
RestartSec = 5

[Install]
WantedBy = multi-user.target
_EOF_

#Start kodi first time to setup user profile folder structure 
sudo systemctl enable kodi.service
sudo systemctl disable kodi.service

#Allow shutdown/reboot from kodi https://yingtongli.me/blog/2016/12/23/kodi-power.html
sudo tee -a /etc/polkit-1/localauthority/50-local.d/all_users_shutdown_reboot.pkla <<_EOF_
[Allow all users to shutdown and reboot]
Identity=unix-user:*
Action=org.freedesktop.login1.*;org.freedesktop.upower.*;org.freedesktop.consolekit.system.*
ResultActive=yes
ResultAny=yes
ResultInactive=yes
_EOF_

#cat /etc/systemd/system/multi-user.target.wants/kodi.service
#ls /etc/polkit-1/localauthority/
#cat /etc/polkit-1/localauthority/50-local.d/all_users
#sudo cat /etc/polkit-1/localauthority/50-local.d/all_users
#sudo cat /etc/polkit-1/localauthority/50-local.d/all_user_shutdown_reboot.pkla

# Start kodi once to allow it to create default .kodi folder and settings don't
# don't use/setup kodi gui yet, wait until this script ends and lookat prepare!
sudo systemctl start kodi.service
echo "Starting kodi to setup defaults, do not configure it yet"
echo "............Kodi will auto close in 60 seconds.........."
sleep 60
sudo systemctl stop kodi.service

#Template with unique variables to be patched by /boot/settings pvr-hts parcing
mkdir /home/pi/.kodi/userdata/addon_data/pvr.hts
tee /home/pi/.kodi/userdata/addon_data/pvr.hts/settings.xml <<_EOF_
<settings>
    <setting id="autorec_approxtime" value="0" />
    <setting id="autorec_maxdiff" value="15" />
    <setting id="connect_timeout" value="10" />
    <setting id="dvr_dubdetect" value="0" />
    <setting id="dvr_lifetime" value="8" />
    <setting id="dvr_priority" value="2" />
    <setting id="epg_async" value="false" />
    <setting id="host" value="192.168.123.123" />
    <setting id="htsp_port" value="9982" />
    <setting id="http_port" value="9981" />
    <setting id="pass" value="htsw" />
    <setting id="pretuner_closedelay" value="10" />
    <setting id="pretuner_enabled" value="false" />
    <setting id="response_timeout" value="5" />
    <setting id="streaming_profile" value="" />
    <setting id="total_tuners" value="2" />
    <setting id="trace_debug" value="false" />
    <setting id="user" value="htsu" />
</settings>
_EOF_

#Template with unique variables to be patched by /boot/settings pvr-isc parcing
mkdir /home/pi/.kodi/userdata/addon_data/pvr.iptvsimple
tee /home/pi/.kodi/userdata/addon_data/pvr.iptvsimple/locsettings.xml <<_EOF_
<settings>
    <setting id="epgCache" value="true" />
    <setting id="epgPath" value="" />
    <setting id="epgPathType" value="1" />
    <setting id="epgTSOverride" value="false" />
    <setting id="epgTimeShift" value="0" />
    <setting id="epgUrl" value="" />
    <setting id="logoBaseUrl" value="" />
    <setting id="logoFromEpg" value="0" />
    <setting id="logoPath" value="" />
    <setting id="logoPathType" value="1" />
    <setting id="m3uCache" value="true" />
    <setting id="m3uPath" value="replacem3u" />
    <setting id="m3uPathType" value="0" />
    <setting id="m3uUrl" value="" />
    <setting id="sep1" value="" />
    <setting id="sep2" value="" />
    <setting id="sep3" value="" />
    <setting id="startNum" value="1" />
</settings>
_EOF_
#Template with unique variables to be patched by /boot/settings pvr-isc parcing
tee /home/pi/.kodi/userdata/addon_data/pvr.iptvsimple/remsettings.xml <<_EOF_
<settings>
    <setting id="epgCache" value="true" />
    <setting id="epgPath" value="" />
    <setting id="epgPathType" value="1" />
    <setting id="epgTSOverride" value="false" />
    <setting id="epgTimeShift" value="0.000000" />
    <setting id="epgUrl" value="" />
    <setting id="logoBaseUrl" value="" />
    <setting id="logoFromEpg" value="0" />
    <setting id="logoPath" value="" />
    <setting id="logoPathType" value="1" />
    <setting id="m3uCache" value="true" />
    <setting id="m3uPath" value="/boot/settings/playlist.m3u" />
    <setting id="m3uPathType" value="1" />
    <setting id="m3uUrl" value="replaceurl" />
    <setting id="sep1" value="" />
    <setting id="sep2" value="" />
    <setting id="sep3" value="" />
    <setting id="startNum" value="1" />
</settings>
_EOF_

#Example keyboard mapping for Numpad navigation usage in kodi
cat <<'_EOF_' > /home/pi/.kodi/userdata/keymaps/keyboard.xml
<keymap>
  <global>
    <keyboard>
      <numpadzero>OSD</numpadzero>
      <numpadone>Stop</numpadone>
      <numpadtwo>Down</numpadtwo>
      <numpadthree>BigStepBack</numpadthree>
      <numpadfour>Left</numpadfour>
      <numpadfive>Select</numpadfive>
      <numpadsix>Right</numpadsix>
      <numpadseven>XBMC.ActivateWindow(Home)</numpadseven>
      <numpadeight>Up</numpadeight>
      <numpadnine>BigStepForward</numpadnine>
      <numpaddivide>StepBack</numpaddivide>
      <!-- my numpad divide shows up as "forwardslash" -->
      <forwardslash>StepBack</forwardslash>
      <numpadtimes>StepForward</numpadtimes>
      <numpadperiod>Info</numpadperiod>
      <numlock>PlayPause</numlock>
      <!-- + and - handle the volume by default -->
      <!-- BackSpace is "back" by default -->
      <!-- Enter is "select" by default -->
      <!-- https://kodi.wiki/view/Alternative_keymaps_for_number_pads -->
    </keyboard>
  </global>
</keymap>
_EOF_

#Create patch file for adjusting defaults in .kodi/userdata/guisettings.xml
cat <<'_EOF_' > gs.patch
--- origuisettings.xml	2018-08-27 20:22:00.774568002 +0200
+++ patchguisettings.xml	2018-08-29 09:52:17.397284881 +0200
@@ -41,7 +41,7 @@
         <volumesteps default="true">90</volumesteps>
     </audiooutput>
     <bluray>
-        <playerregion default="true">1</playerregion>
+        <playerregion>2</playerregion>
     </bluray>
     <cache>
         <harddisk default="true">256</harddisk>
@@ -70,23 +70,23 @@
         <showloginfo default="true">false</showloginfo>
     </debug>
     <disc>
-        <playback default="true">0</playback>
+        <playback>2</playback>
     </disc>
     <dvds>
-        <automenu default="true">false</automenu>
+        <automenu>true</automenu>
         <autorun default="true">false</autorun>
         <playerregion default="true">0</playerregion>
     </dvds>
     <epg>
         <daystodisplay default="true">3</daystodisplay>
-        <epgupdate default="true">120</epgupdate>
+        <epgupdate>360</epgupdate>
         <hidenoinfoavailable default="true">true</hidenoinfoavailable>
         <ignoredbforclient default="true">false</ignoredbforclient>
-        <preventupdateswhileplayingtv default="true">false</preventupdateswhileplayingtv>
+        <preventupdateswhileplayingtv>true</preventupdateswhileplayingtv>
         <selectaction default="true">2</selectaction>
     </epg>
     <eventlog>
-        <enabled default="true">true</enabled>
+        <enabled>false</enabled>
         <enablednotifications default="true">false</enablednotifications>
     </eventlog>
     <filelists>
@@ -102,13 +102,13 @@
         <addonbrokenfilter default="true">true</addonbrokenfilter>
         <addonforeignfilter default="true">false</addonforeignfilter>
         <addonnotifications default="true">false</addonnotifications>
-        <addonupdates default="true">0</addonupdates>
-        <settinglevel>1</settinglevel>
+        <addonupdates>2</addonupdates>
+        <settinglevel>3</settinglevel>
         <eventlog>
             <level>0</level>
             <showhigherlevels>true</showhigherlevels>
         </eventlog>
-        <systemtotaluptime>0</systemtotaluptime>
+        <systemtotaluptime>10</systemtotaluptime>
     </general>
     <input>
         <asknewcontrollers default="true">true</asknewcontrollers>
@@ -119,13 +119,13 @@
     <locale>
         <audiolanguage default="true">original</audiolanguage>
         <charset default="true">DEFAULT</charset>
-        <country default="true">USA (12h)</country>
+        <country>Central Europe</country>
         <keyboardlayouts default="true">English QWERTY</keyboardlayouts>
         <language default="true">resource.language.en_gb</language>
         <longdateformat default="true">regional</longdateformat>
         <shortdateformat default="true">regional</shortdateformat>
         <speedunit default="true">regional</speedunit>
-        <subtitlelanguage default="true">original</subtitlelanguage>
+        <subtitlelanguage>Dutch</subtitlelanguage>
         <temperatureunit default="true">regional</temperatureunit>
         <timeformat default="true">regional</timeformat>
         <timezone default="true">Europe/Amsterdam</timezone>
@@ -172,7 +172,7 @@
         <queuebydefault default="true">false</queuebydefault>
         <replaygainnogainpreamp default="true">89</replaygainnogainpreamp>
         <replaygainpreamp default="true">89</replaygainpreamp>
-        <replaygaintype default="true">1</replaygaintype>
+        <replaygaintype>0</replaygaintype>
         <seekdelay default="true">750</seekdelay>
         <seeksteps default="true">-60,-30,-10,10,30,60</seeksteps>
         <visualisation default="true">visualization.spectrum</visualisation>
@@ -213,7 +213,7 @@
         <usehttpproxy default="true">false</usehttpproxy>
     </network>
     <pictures>
-        <displayresolution default="true">14</displayresolution>
+        <displayresolution>16</displayresolution>
         <generatethumbs default="true">true</generatethumbs>
         <showvideos default="true">true</showvideos>
         <usetags default="true">true</usetags>
@@ -225,10 +225,10 @@
         <wakeonaccess default="true">false</wakeonaccess>
     </powermanagement>
     <pvrmanager>
-        <backendchannelorder default="true">true</backendchannelorder>
+        <backendchannelorder>false</backendchannelorder>
         <hideconnectionlostwarning default="true">false</hideconnectionlostwarning>
         <syncchannelgroups default="true">true</syncchannelgroups>
-        <usebackendchannelnumbers default="true">false</usebackendchannelnumbers>
+        <usebackendchannelnumbers>true</usebackendchannelnumbers>
     </pvrmanager>
     <pvrmenu>
         <closechannelosdonswitch default="true">true</closechannelosdonswitch>
@@ -248,7 +248,7 @@
         <playminimized default="true">true</playminimized>
         <scantime default="true">10</scantime>
         <signalquality default="true">true</signalquality>
-        <startlast default="true">0</startlast>
+        <startlast>2</startlast>
         <trafficadvisory default="true">false</trafficadvisory>
         <trafficadvisoryvolume default="true">10</trafficadvisoryvolume>
     </pvrplayback>
@@ -281,14 +281,14 @@
     </scrapers>
     <screensaver>
         <mode default="true">screensaver.xbmc.builtin.dim</mode>
-        <time default="true">3</time>
+        <time>20</time>
         <usedimonpause default="true">true</usedimonpause>
         <usemusicvisinstead default="true">true</usemusicvisinstead>
     </screensaver>
     <services>
-        <airplay default="true">false</airplay>
+        <airplay>true</airplay>
         <airplaypassword default="true"></airplaypassword>
-        <airplayvideosupport default="true">true</airplayvideosupport>
+        <airplayvideosupport>false</airplayvideosupport>
         <airplayvolumecontrol default="true">true</airplayvolumecontrol>
         <devicename default="true">Kodi</devicename>
         <esallinterfaces default="true">false</esallinterfaces>
@@ -330,7 +330,7 @@
         <downloadfirst default="true">false</downloadfirst>
         <font default="true">arial.ttf</font>
         <height default="true">28</height>
-        <languages default="true">English</languages>
+        <languages>Dutch,English</languages>
         <movie default="true"></movie>
         <overrideassfonts default="true">false</overrideassfonts>
         <parsecaptions default="true">false</parsecaptions>
@@ -357,11 +357,11 @@
         <updateonstartup default="true">false</updateonstartup>
     </videolibrary>
     <videoplayer>
-        <adjustrefreshrate default="true">0</adjustrefreshrate>
+        <adjustrefreshrate>2</adjustrefreshrate>
         <autoplaynextitem default="true">false</autoplaynextitem>
         <errorinaspect default="true">0</errorinaspect>
         <hqscalers default="true">20</hqscalers>
-        <limitguiupdate default="true">10</limitguiupdate>
+        <limitguiupdate>5</limitguiupdate>
         <preferdefaultflag default="true">true</preferdefaultflag>
         <prefervaapirender default="true">true</prefervaapirender>
         <quitstereomodeonstop default="true">true</quitstereomodeonstop>
@@ -412,11 +412,11 @@
         <fakefullscreen default="true">true</fakefullscreen>
         <framepacking default="true">false</framepacking>
         <limitedrange default="true">false</limitedrange>
-        <limitgui default="true">0</limitgui>
+        <limitgui>720</limitgui>
         <monitor default="true">Default</monitor>
         <noofbuffers default="true">2</noofbuffers>
         <preferedstereoscopicmode default="true">100</preferedstereoscopicmode>
-        <resolution default="true">16</resolution>
+        <resolution>49</resolution>
         <screen default="true">0</screen>
         <screenmode default="true">DESKTOP</screenmode>
         <stereoscopicmode default="true">0</stereoscopicmode>
_EOF_
cp /home/pi/.kodi/userdata/guisettings.xml /home/pi/origuisettings.xml
patch /home/pi/.kodi/userdata/guisettings.xml gs.patch

#Defaults for Enabling/Disabling Buttons in HomeMenu skin
mkdir /home/pi/.kodi/userdata/addon_data/skin.estuary
cat <<'_EOF_' >/home/pi/.kodi/userdata/addon_data/skin.estuary/settings.xml
<settings>
    <setting id="no_slide_animations" type="bool">false</setting>
    <setting id="HomeMenuNoPicturesButton" type="bool">false</setting>
    <setting id="no_fanart" type="bool">false</setting>
    <setting id="HomeMenuNoMovieButton" type="bool">true</setting>
    <setting id="HomeMenuNoTVShowButton" type="bool">true</setting>
    <setting id="HomeMenuNoMusicButton" type="bool">true</setting>
    <setting id="HomeMenuNoMusicVideoButton" type="bool">true</setting>
    <setting id="HomeMenuNoTVButton" type="bool">false</setting>
    <setting id="HomeMenuNoRadioButton" type="bool">false</setting>
    <setting id="HomeMenuNoProgramsButton" type="bool">false</setting>
    <setting id="HomeMenuNoVideosButton" type="bool">false</setting>
    <setting id="HomeMenuNoFavButton" type="bool">true</setting>
    <setting id="HomeMenuNoWeatherButton" type="bool">true</setting>
    <setting id="touchmode" type="bool">false</setting>
    <setting id="show_weatherinfo" type="bool">false</setting>
    <setting id="autoscroll" type="bool">false</setting>
    <setting id="hide_mediaflags" type="bool">false</setting>
    <setting id="background_overlay" type="string">1</setting>
    <setting id="MovieGenreFanart.path" type="string"></setting>
    <setting id="MovieGenreFanart.ext" type="string"></setting>
    <setting id="WeatherFanart.path" type="string"></setting>
    <setting id="WeatherFanart.ext" type="string"></setting>
    <setting id="HomeFanart.path" type="string"></setting>
    <setting id="HomeFanart.ext" type="string"></setting>
    <setting id="HomeFanart.name" type="string"></setting>
    <setting id="WeatherFanart.name" type="string"></setting>
    <setting id="MovieGenreFanart.Name" type="string"></setting>
</settings>
_EOF_

echo "The automated part is done, now its time to configure kodi GUI to a state"
echo "you want it to be as a template for every single readonly boot for future"
echo "Run './rrk.sh modifykodirw' to see steps to create its definitive state"
}

function modifykodirw {
echo "
The idea is that you will start kodi this time to configure it with hdmi-cec or
mouse/keyboard to its final setup/look/state which will be used as a definitive
template for the readonly environment. You are free to install any Video addon.

Its important to keep a certain order of addon installation since the pvr addons
will be enabled (not configured) at the end. All other addons configured after 
the first pvr addon will get lost! 

Keep in mind diskspace/ram usage since the whole .kodi folder will stay in ram
when its in read-only mode! Especially avoid addons that build huge thumbcaches!
To check kodi folder size type 'du -hcs ~.kodi' those are MB of RAM starving!

Final warning do not configure/change settings in the enabled PVR-addons nor
changes in the audio output since otherwise /boot/setting configurations fail 
to apply!

################################################################################

sudo systemctl start kodi.service
#setup kodi&addons as usual but before enabling the first pvr addon exit kodi
#
#if kodi has been exited create a backup of the addon database with none pvr!
sudo cp -a /home/pi/.kodi/userdata/Database/Addons27.db /home/pi/nonAddons27.db

sudo systemctl start kodi.service
#setup kodi&addons as usual but after enabling the first pvr-hts addon exit kodi
#
#if kodi has been exited after enabling the pvr-hts addon backup its database!
sudo cp -a /home/pi/.kodi/userdata/Database/Addons27.db /home/pi/htsAddons27.db

sudo systemctl start kodi.service
#start kodi again to disable pvr-hts addon than enable pvr-isc addon and exit 
#
#if kodi has been exited after enabling the pvr-isc addon backup its database!
sudo cp -a /home/pi/.kodi/userdata/Database/Addons27.db /home/pi/iscAddons27.db

sudo systemctl start kodi.service
#start kodi again to disable pvr-isc addon than enable pvr-hhr addon and exit 
#
#if kodi has been exited after enabling the pvr-hhr addon backup its database!
sudo cp -a /home/pi/.kodi/userdata/Database/Addons27.db /home/pi/hhrAddons27.db

################################################################################

When a definitive kodi state is reached the final step must be run to make it 
readonly proof therefor run './rrk.sh finishkodiro' and answer script questions. 
"
}

function finishkodiro {
sudo systemctl stop kodi.service
cp -a /home/pi/.kodi /home/pi/kodiro
rm -r /home/pi/.kodi
cp -a /home/pi/kodiro /tmp/kodirw
sudo ln -s /tmp/kodirw /home/pi/.kodi

head -n 20 /etc/rc.local | sudo tee /etc/rc.local
sudo tee -a /etc/rc.local <<_EOF_

echo "[  DO  ] copy kodiro to /tmp/kodirw"
cp -a /home/pi/kodiro /tmp/kodirw
sync
echo "[  DO  ] running /home/pi/setaudio.sh"
/home/pi/setaudio.sh
echo "[  DO  ] running /home/pi/setpvr.sh"
/home/pi/setpvr.sh
echo "[  DO  ] running /home/pi/connectwii.sh"
/home/pi/connectwii.sh

sync
sleep 1
sudo systemctl start kodi.service

exit 0
_EOF_

wget https://raw.githubusercontent.com/adafruit/Raspberry-Pi-Installer-Scripts/master/read-only-fs.sh
sudo bash /home/pi/read-only-fs.sh

echo "
You are done just reboot!
"
}

function joystickcontroller {
#buttonmaps for classic- v1/v2/logitech & modern- 360 xbpx wired usb controllers 
mkdir ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux
mkdir ~/.kodi/userdata/peripheral_data

cat <<'_EOF_' > ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Logitech_Compact_Controller_for_Xbox_10b_8a.xml
<?xml version="1.0" ?>
<buttonmap>
    <device name="Logitech Compact Controller for Xbox" provider="linux" buttoncount="10" axiscount="8">
        <configuration>
            <axis index="2" center="-1" range="2" />
            <axis index="5" center="-1" range="2" />
        </configuration>
        <controller id="game.controller.default">
            <feature name="a" button="0" />
            <feature name="b" button="1" />
            <feature name="back" button="6" />
            <feature name="down" axis="+7" />
            <feature name="left" axis="-6" />
            <feature name="leftbumper" button="5" />
            <feature name="leftstick">
                <up axis="-1" />
                <down axis="+1" />
                <right axis="+0" />
                <left axis="-0" />
            </feature>
            <feature name="leftthumb" button="8" />
            <feature name="lefttrigger" axis="+2" />
            <feature name="right" axis="+6" />
            <feature name="rightbumper" button="2" />
            <feature name="rightstick">
                <up axis="-4" />
                <down axis="+4" />
                <right axis="+3" />
                <left axis="-3" />
            </feature>
            <feature name="rightthumb" button="9" />
            <feature name="righttrigger" axis="+5" />
            <feature name="start" button="7" />
            <feature name="up" axis="-7" />
            <feature name="x" button="3" />
            <feature name="y" button="4" />
        </controller>
    </device>
</buttonmap>
_EOF_

# set global deadzone for all controller to 0.8 since the slightest stick offset 
# will hang/repeat unwanted input and make GUI unresponsive!

#cat <<'_EOF_' > ~/.kodi/userdata/peripheral_data/addon_Logitech_Compact_Controller_for_Xbox.xml
#addon_Microsoft_X-Box_pad_v1_(US)
#addon_Microsoft_X-Box_pad_v2_(US)
#addon_Microsoft_X-Box_360_pad
#<settings>
#    <setting id="left_stick_deadzone" value="0.90" />
#    <setting id="right_stick_deadzone" value="0.90" />
#</settings>
#_EOF_

cat <<'_EOF_' > ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Microsoft_X-Box_pad_v1_US_10b_8a.xml
<?xml version="1.0" ?>
<buttonmap>
    <device name="Microsoft X-Box pad v1 (US)" provider="linux" buttoncount="10" axiscount="8">
        <configuration>
            <axis index="2" center="-1" range="2" />
            <axis index="5" center="-1" range="2" />
        </configuration>
        <controller id="game.controller.default">
            <feature name="a" button="0" />
            <feature name="b" button="1" />
            <feature name="back" button="6" />
            <feature name="down" axis="+7" />
            <feature name="left" axis="-6" />
            <feature name="leftbumper" button="5" />
            <feature name="leftstick">
                <up axis="-1" />
                <down axis="+1" />
                <right axis="+0" />
                <left axis="-0" />
            </feature>
            <feature name="leftthumb" button="8" />
            <feature name="lefttrigger" axis="+2" />
            <feature name="right" axis="+6" />
            <feature name="rightbumper" button="2" />
            <feature name="rightstick">
                <up axis="-4" />
                <down axis="+4" />
                <right axis="+3" />
                <left axis="-3" />
            </feature>
            <feature name="rightthumb" button="9" />
            <feature name="righttrigger" axis="+5" />
            <feature name="start" button="7" />
            <feature name="up" axis="-7" />
            <feature name="x" button="3" />
            <feature name="y" button="4" />
        </controller>
    </device>
</buttonmap>
_EOF_

cat <<'_EOF_' > ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Microsoft_X-Box_pad_v2_US_10b_8a.xml
<?xml version="1.0" ?>
<buttonmap>
    <device name="Microsoft X-Box pad v2 (US)" provider="linux" buttoncount="10" axiscount="8">
        <configuration>
            <axis index="2" center="-1" range="2" />
            <axis index="5" center="-1" range="2" />
        </configuration>
        <controller id="game.controller.default">
            <feature name="a" button="0" />
            <feature name="b" button="1" />
            <feature name="back" button="6" />
            <feature name="down" axis="+7" />
            <feature name="left" axis="-6" />
            <feature name="leftbumper" button="5" />
            <feature name="leftstick">
                <up axis="-1" />
                <down axis="+1" />
                <right axis="+0" />
                <left axis="-0" />
            </feature>
            <feature name="leftthumb" button="8" />
            <feature name="lefttrigger" axis="+2" />
            <feature name="right" axis="+6" />
            <feature name="rightbumper" button="2" />
            <feature name="rightstick">
                <up axis="-4" />
                <down axis="+4" />
                <right axis="+3" />
                <left axis="-3" />
            </feature>
            <feature name="rightthumb" button="9" />
            <feature name="righttrigger" axis="+5" />
            <feature name="start" button="7" />
            <feature name="up" axis="-7" />
            <feature name="x" button="3" />
            <feature name="y" button="4" />
        </controller>
    </device>
</buttonmap>
_EOF_

cat <<'_EOF_' > ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Microsoft_X-Box_360_pad_11b_8a.xml
<?xml version="1.0" ?>
<buttonmap>
    <device name="Microsoft X-Box 360 pad" provider="linux" buttoncount="11" axiscount="8">
        <configuration>
            <axis index="2" center="-1" range="2" />
            <axis index="5" center="-1" range="2" />
        </configuration>
        <controller id="game.controller.default">
            <feature name="a" button="0" />
            <feature name="b" button="1" />
            <feature name="back" button="6" />
            <feature name="down" axis="+7" />
            <feature name="guide" button="8" />
            <feature name="left" axis="-6" />
            <feature name="leftbumper" button="4" />
            <feature name="leftstick">
                <up axis="-1" />
                <down axis="+1" />
                <right axis="+0" />
                <left axis="-0" />
            </feature>
            <feature name="leftthumb" button="9" />
            <feature name="lefttrigger" axis="+2" />
            <feature name="right" axis="+6" />
            <feature name="rightbumper" button="5" />
            <feature name="rightstick">
                <up axis="-4" />
                <down axis="+4" />
                <right axis="+3" />
                <left axis="-3" />
            </feature>
            <feature name="rightthumb" button="10" />
            <feature name="righttrigger" axis="+5" />
            <feature name="start" button="7" />
            <feature name="up" axis="-7" />
            <feature name="x" button="2" />
            <feature name="y" button="3" />
        </controller>
    </device>
</buttonmap>
_EOF_

#adjust generic joystick deadzone level to reduce false/freezing/repeating input 
sudo sed -i 's/value="0.2"/value="0.8"/g' /usr/share/kodi/system/peripherals.xml
}

function joywii {
sudo tee -a /boot/settings/WIIMOTE.txt <<_EOF_
#Discover WiiMote macaddress with 'hcitool scan' while pressing 1&2 buttons!
#uncomment and replace the macaddress below with the one you discovered! 
#wiimacaddress=FF:FF:FF:FF:FF:FF
_EOF_

sudo apt-get -y install lswm wminput #kodi-eventclients-wii?
echo 'KERNEL=="uinput", MODE="0666"' | sudo tee /etc/udev/rules.d/wiimote.rules
cat <<'_EOF_' > ~/wminput1
#WiiMote
Wiimote.A = BTN_A
Wiimote.B = BTN_B
Wiimote.Dpad.X = ABS_Y
Wiimote.Dpad.Y = -ABS_X
Wiimote.Minus = BTN_SELECT
Wiimote.Plus = BTN_START
Wiimote.Home = BTN_MODE
Wiimote.1 = BTN_X
Wiimote.2 = BTN_Y
# Nunchuk
Nunchuk.C = BTN_C
Nunchuk.Z = BTN_Z
Plugin.led.Led1 = 1
#Plugin.led.Led2 = 1
Plugin.led.Led3 = 1
#Plugin.led.Led4 = 1
_EOF_

cat <<'_EOF_' > ~/connectwii.sh
#!/bin/bash
sleep 1 # Wait until Bluetooth services are fully initialized
#detect modified mac FF:FF:FF:FF:FF:FF otherwise service won't start?
case $(cat /boot/settings/WIIMOTE.txt | grep -v '#' | sed -e 's/=.*//' -) in
    wiimacaddress)
    hcitool dev | grep hci >/dev/null
    if test $? -eq 0 ; then
        WIIMAC=$(cat /boot/settings/WIIMOTE.txt | grep -v '#' | grep wiimacaddress | sed -e 's/wiimacaddress=//g' -)
        wminput -q -d -c  /home/pi/wminput1 $WIIMAC > /dev/null 2>&1 &
        echo "[  OK  ] connect Wiimote press 1+2 button!"
    else
        echo "[  NO  ] failed Wiimote no bluetooth adapter!"
        exit 0
    fi
    ;;
esac
exit 0
_EOF_

chmod +x ~/connectwii.sh

#sudo service udev restart
#sudo modprobe uinput #requires reboot because current outdated kernel missed

#sudo sed -i 's|^ExecStart=/usr/lib/bluetooth/bluetoothd$|ExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=sap|' /lib/systemd/system/bluetooth.service
#sudo adduser pi bluetooth
#hciutil scan #find mac address of wiimote(press 1+2 buttons simultanious to detect and connect)

cat <<'_EOF_' > ~/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Nintendo_Wiimote_9b_2a.xml
<?xml version="1.0" ?>
<buttonmap>
    <device name="Nintendo Wiimote" provider="linux" buttoncount="9" axiscount="2">
        <configuration />
        <controller id="game.controller.gba">
            <feature name="a" button="0" />
            <feature name="b" button="1" />
            <feature name="down" axis="+0" />
            <feature name="left" axis="-1" />
            <feature name="leftbumper" button="6" />
            <feature name="right" axis="+1" />
            <feature name="rightbumper" button="7" />
            <feature name="select" button="4" />
            <feature name="start" button="3" />
            <feature name="up" axis="-0" />
        </controller>
    </device>
</buttonmap>
_EOF_
}

function gpioirlirc {
sudo apt-get -y install ir-keytable evtest lirc #inputlirc==eventlird
#disable inputloop to fix repeating button presses
sudo systemctl stop lircd-uinput
sudo systemctl disable lircd-uinput
#sudo systemctl stop lircd
#rc_maps keyfile libreelecmulti?
#sudo ir-keytable -t #test remote input via kernel
#sudo evtest
#sudo systemctl start lircd
#sudo irw #test remote input via lirc
#cat /proc/bus/input/devices
echo 'KERNEL=="event*",ATTRS{name}=="gpio_ir_recv",SYMLINK="input/irremote"' | sudo tee /etc/udev/rules.d/10-persistent-ir.rules
cp /usr/share/kodi/system/Lircmap.xml ~/.kodi/userdata/
sed -i "s|<altname>cx23885_remote</altname>|<altname>/dev/input/irremote</altname>|g" ~/.kodi/userdata/Lircmap.xml
sed -i "s|<title>KEY_EPG</title>|<guide>KEY_EPG</guide>|g" ~/.kodi/userdata/Lircmap.xml
sudo systemctl restart udev
sudo udevadm trigger
sudo systemctl restart lircd

}

function startsetup {
firstbootupgrades
performancetweaks
setlocaldefaults
extraconfigs
installkodi
joystickcontroller
joywii
gpioirlirc
}

$ACTIONIS
exit 0
