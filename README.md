# roraspbiankodi
A recipe for turning 'raspbian-lite' stretch into a 'read-only-fs' power outage/powercut proof 'kodi' appliance. 
Configurable by /boot available config files/flags for setting audio/network/nfs/pvr-frontends(TvHeadend/IPTVsimpleclient/HDHomerun).

## Why?
It will always do what it was ment to do for, boot after (re)boot after... powercut! For example when a raspberry pi zero is used as a TV tuner(smartv applicance), USB powered and controlled(HDMI-cec remote) from the very same television it may accidently be powered on and off by hitting the 'red' button from your TV-remote, without worying that it won't boot the next time because it will boot.

## Start!
Just image a default raspbian-lite image to a 2GB SD-card like you would normally do and add a 'ssh' file to its /boot partition. Connect your raspberrypi to a network &monitor(keyboard/mouse)/tv(remote) power it on and ssh into it and get 'rrk.sh' script:

```
#get script
wget https://raw.githubusercontent.com/walterav1984/roraspbiankodi/master/rrk.sh

#if it fails
sudo apt-get update
sudo apt-get -y install curl
curl -o https://raw.githubusercontent.com/walterav1984/roraspbiankodi/master/rrk.sh

#make script executable
chmod +x rrk.sh

#run first automated step ~15minutes
./rrk.sh startsetup

#read second step, besides gui interaction its only 6 cli steps
./rrk.sh modifykodirw

#run third step and answer y n n n y n
./rrk.sh finishkodiro

#after this you have a functional but still unconfigured sdcard
#look at the config files in /boot/settings for audio/netwerk/pvr
#they will make sense what and howto configure for instance

```
Example to configure the sdcard for iptvsimpleclient remote url and analogue audio output:

```
/boot/settings/PVRCONF.txt
#uncomment 'itsclient' but comment #tvheadend

/boot/settings/ISCCONF.txt
#uncomment 'remote' and fillin correct url than comment #local

/boot/settings/AUDIOout.conf
#uncomment Analogue and comment HDMI
```
For wifi it behaves same as raspbian, but as an extra you can setup static ipaddress directly by editing /boot/settings/dhcpcd.conf there.

## How?
It starts with a raspbian-lite image that with the help of the 'rrk.sh'(linking to adafruit read-only-fs.sh) script will be turned into a readonly kodi appliance in roughly 4 steps from which 2 are automated 1cumbersome to explain and 1easy.

First step is fully automatic and initiated by running './rrk startsetup' it will do some updating and cleanup of the raspbian OS and install kodi including some pvr-addons and set some defaults and scripts.

Second step is fully manual and requires user interaction on the Raspberry Pi itself via Keyboard/Remote in the kodi GUI completed with just 6 ssh commands. This is the stage where you can/must alter/configure kodi to its defenitive state/appearance before going readonly.
It may sound difficult but after the './rrk startsetup' finishes, just manually start kodi via ssh and setup kodi as you would normally do, like skin settings or install(not enable pvr clients) addons.
However when it comes to finally enabling pvr-clients just start with tvheadend(although you may not even use it do it), you must only enable a "single" pvr-addon at the time and not configure it after enabling just exit kodi(not shutdown/reboot) and go back to ssh and backup the tvheadend enabled hardcodec database file "htsAddons27.db". Than repeat in the sense of starting kodi again, but only disabling previous enabled pvr-hts addon for tvheadend and enabling pvr-iptvsimpleclient instead this time but still not configure it just exit kodi again. With ssh again copy the database with iptvsimpleclient enabled this time "iscAddons27.db". Finally repeat again but than disable pvr-iptvsimpleclient and enable pvr hdhomerun exit after it and via ssh make a copy again of the database "hhrAddons.db" These 6 exact ssh steps are shown when running the command 'rrk.sh modifykodirw'! These steps makes it possible to choose a pvr-client in PVRTYPE.conf from the /boot/settings by just overwritting the Addons27.db file in the background without notice.

Third step is automated but only requires answering a few 'y/n' steps to the [adafruit read-only-fs.sh](https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/blob/master/read-only-fs.sh)" that is run in the back and than the image will be done(still not configured) after you shutdown the pi gracefully.

Finally in step four edit /boot/settings/*.conf files to you need, these settings can be changed anytime and form the only flexable way of adjusting your now readonly behaving system! Just remember that these boot/settings are parsed during boot so altering them when running the pi even in rw mode doesn't make them active.

This was just a summary/proof of concept but usable since kodi 18 does some major code rewrites including a retrogame api don't expect much improvements.

## TODO
* audio Analogue raspberry pop tick crackle
* retrogame backend wait for kodi 18
* vcgencmd measure_clock pixel #sync to display adjust rerfreshrate?
* startupscreen tvlist?
* ir remote?ir-keytable inputlirc r-keytable -r ir-keytable -t

## Debug/Think
```
/opt/vc/bin/tvservice -p
/opt/vc/bin/tvservice -o
echo "standby 0" | cec-client RPI -s -d 1

sudo apt-get install cec-utils
echo "scan" | cec-client RPI -s -d 1

echo "standby 0" | cec-client RPI -s -d 1
echo "as" | cec-client RPI -s -d 1

echo $KODI_HOME
echo $KODI_TEMP
cat .profile 
nano /etc/environment 
kodi-standalone 
```

## LINKS
* [adjust refresh and sync to monitor?](https://forum.kodi.tv/showthread.php?tid=263052)
* [read-only raspbian manual](https://hallard.me/raspberry-pi-read-only)
* [adafruit read-only raspbian script](https://learn.adafruit.com/read-only-raspberry-pi/overview)
* [GPU mem setting](https://forum.libreelec.tv/thread/611-rendering-issues-font-corruption/)
* [kodi shutdown options](https://www.raspberrypi.org/forums/viewtopic.php?t=192499)
* [raspbian stretch kodi](https://yingtongli.me/blog/2016/12/23/kodi-power.html)
