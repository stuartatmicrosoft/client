#!/bin/bash

# Written by Stuart Kirk
# stuart.kirk@microsoft.com
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo " "
echo " "

echo "Downloading latest Azure tuneable file..."
echo "*****************************************"
wget -N -q -P /etc/sysctl.d https://raw.githubusercontent.com/stuartatmicrosoft/bitbucket/master/98-rhel7-azure-sysctl.conf

echo " "
echo " "

echo "Setting SELinux Context..."
echo "**************************"
chcon --reference=/etc/sysctl.conf /etc/sysctl.d/98-rhel7-azure-sysctl.conf

echo " "
echo " "

echo "Calling sysctl to re-read configuration..."
echo "******************************************"
/usr/sbin/sysctl -q --system

echo " "
echo " "

echo "Installing epel-release, deltarpm and telnet RPMs..."
echo "****************************************************"
yum -q -y install epel-release deltarpm telnet

echo " "
echo " "

echo "Verifying accelerated networking is available..."
echo "************************************************"
if [ -n "`lspci |grep -i mellanox`" ]
then
   echo -e "${GREEN}Verified.${NC}"
else
   echo -e "Accelerated networking is ${RED}*NOT*${NC} available on this host!"
fi

echo " "
echo " "

echo "Verifying accelerated networking is functioning..."
echo "**************************************************"
if [ "`ethtool -S eth0 | grep -v cpu | grep vf_rx_bytes |awk '{print $2}'`" -gt "0" ]
then
   echo -e "Accelerated networking is ${GREEN}enabled${NC} and appears to be functioning."
else
   echo -e "Accelerated networking does ${RED}*NOT*${NC} appear to be functioning."
fi

echo " "
echo " "

echo "Checking if SCSI blk-mq is enabled on this host..."
echo "**************************************************"
if [ "`cat /sys/module/scsi_mod/parameters/use_blk_mq | tr '[:upper:]' '[:lower:]'`" = "n"  ]; then
 if [ -n "`grep -i "scsi_mod.use_blk_mq=y" /boot/grub2/grub.cfg`" ]; then
  echo -e "SCSI blk-mq is ${RED}*NOT*${NC} currently enabled on this host, however the grub configuration file has been updated to ${GREEN}enable${NC} it on next boot."
  exit 0
 fi
 echo -e "SCSI blk-mq is ${RED}*NOT*${NC} enabled. Adding."
 sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& scsi_mod.use_blk_mq=Y/' /etc/default/grub
 echo "Validating that /etc/default/grub has been updated."
 if [ -n "`grep -i "scsi_mod.use_blk_mq=y" /etc/default/grub`" ]; then
  echo "Re-making the host grub2.cfg"
  grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
 else
  echo "Unable to patch grub.cfg. Exiting."
  exit 1
 fi
 echo "Validating that /boot/grub2/grub.cfg has been updated."
 if [ -n "`grep -i "scsi_mod.use_blk_mq=y" /boot/grub2/grub.cfg`" ]; then
  echo "Changes to /boot/grub2/grub.cfg are successful and will take effect on next reboot"
 fi
else
 echo -e "SCSI blk-mq is already ${GREEN}enabled${NC} on this host."
fi
