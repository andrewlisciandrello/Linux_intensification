#!/bin/bash

pre_work(){
  clear
  echo "################################################################################"
  echo "Skipping RHN automagic installation
  https://one.rackspace.com/display/SegSup/RHN+Registration

  wget http://dfw.rhn.rackspace.com/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm
  yum -y --nogpgcheck localinstall rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm

# Visit: https://api.rhn.rackspace.com/cgi-bin/api/api.cgi?debug=1&device=$server_number (see note below for auth info). The device number is the core device number being registered. The output will contain an rhnreg_ks command to copy and execute on the server.
# Get password here: https://portal.rhn.rackspace.com/OTP

Then do the following:
rpm --import /etc/pki/rpm-gpg/RACKSPACE-GPG-KEY
rpm --import /etc/pki/rpm-gpg/IUS-RHN-GPG-KEY
yum -y --nogpgcheck install rs-tools rs-release

"
  echo "You NEED to configure this BEFORE running this script"
  echo "################################################################################"
  read -p "If the above is done please press [enter] to continue"
  clear
  echo "################################################################################"

echo "

JUST USE OPEN-VM-TOOLS!

"


  echo "skipping VMware tools automagic installation"
  echo "because this is RHEL6, you should be able to do the following"
  echo "
#  yum -y remove vmware* && yum -y remove vmware-open*
#  mv /etc/yum.repos.d/vmware-tools.repo /etc/yum.repos.d/vmware-tools.repo.bak
#  rm -rf /etc/vmware*; rm -rf /usr/lib/vmware*; rm -f /usr/bin/vmware*
#  echo '[vmware-tools]' > /etc/yum.repos.d/vmware-tools.repo
#  echo 'name=VMware Tools' >> /etc/yum.repos.d/vmware-tools.repo
#  echo 'baseurl=http://packages.vmware.com/tools/esx/5.5u2/rhel6/x86_64' >> /etc/yum.repos.d/vmware-tools.repo
#  echo 'enabled=1' >> /etc/yum.repos.d/vmware-tools.repo
#  echo 'gpgcheck=1' >> /etc/yum.repos.d/vmware-tools.repo
#  echo 'gpgkey=http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub' >> /etc/yum.repos.d/vmware-tools.repo

#  yum --enablerepo=vmware-tools clean metadata
#  yum install -y pyxf86config vmware-tools-core vmware-tools-esx-kmods vmware-tools-esx-nox

"
  echo "You SHOULD configure this BEFORE running this script (make sure VMware tools not already installed/up-to-date)"
  echo "################################################################################"
  read -p "If the above is done please press [enter] to continue"
  clear
  echo "################################################################################"

  echo "Skipping automagic configuration of AD/LDAP"
  echo ""
  echo "Follow the instructions here: https://one.rackspace.com/x/BpggBw"
  echo "You can configure this AFTER running this script"

  echo "################################################################################"
  read -p "please press [enter] to acknowledge this message and begin configuration"
  clear
  echo "################################################################################"
}

start() {
  echo "################################################################################"
  if [ "$EUID" -ne 0 ] ; then
    echo "I need to run as root"
    exit
  fi
  logger "Starting automation to raxify/instensify this server"

  echo "Enter New Hostname:"
  read NEW_NAME
  echo ""

  echo "Please enter new External IP Address"
  read new_external_ip
  echo ""

  echo "Please enter Customer Number"
  read customer_number
  echo ""

  echo "Please enter DataCenter"
  read datacenter
  echo ""

  echo "Please enter Primary User"
  read primary_user
  echo ""

  echo "Please enter segment (Managed/Intensive)"
  read segment
  echo ""

  echo "Select Nimbus probes (probably either Intensiveprobes-RHEL6, Intensiveprobes-RHEL7, or ManagedProbes)"
  read nimbus_probes
  echo ""

  echo "Please Enter Server Number"
  read server_number
  echo ""
  echo "################################################################################"
}

bkup_configs() {
  echo "################################################################################"
  echo "backing up files before any edits, resolv.conf,hosts,etc."
  logger "backing up files before any edits, resolv.conf,hosts,etc."
  if [ -d /root/pre-intensification-backup ] ; then
    mv /root/pre-intensification-backup /root/pre-intensification-backup.$(date +%F_%R)
  fi
  mkdir /root/pre-intensification-backup/ ; cd /root/pre-intensification-backup/
  netstat -nutlp|awk -F'[ /]+' '/tcp/ {print $8,$1,$4}'|sort|column -t > /root/pre-intensification-backup/netstat.pre
  ps aux > /root/pre-intensification-backup/ps.pre
  df -h > /root/pre-intensification-backup/df.pre
  ip a > /root/pre-intensification-backup/ip.pre
  cp /etc/resolv.conf /root/pre-intensification-backup/resolv.pre
  cp /etc/hosts /root/pre-intensification-backup/hosts.pre
  cp /etc/sysconfig/network /root/pre-intensification-backup/sysconfignetwork.pre
  cp /etc/sysconfig/network-scripts/ifcfg-* /root/pre-intensification-backup/.
  uname -a > /root/pre-intensification-backup/uname.pre
  cd ~
  echo ""
  echo "################################################################################"
}


ip_config(){
  echo "################################################################################"
  echo "we are not changing any IPs automagically"
  echo ""
  echo "################################################################################"
}


set_hostname() {
  echo "################################################################################"
  OLD_NAME=$(hostname)
  echo "Current Hostname is $OLD_NAME"
  echo "New Hostname is $NEW_NAME"
  echo ""

if [[ -n "$NEW_NAME" ]] ; then

  OLDSHORT=$(echo "$OLD_NAME" | cut -d. -f1)
  NEWSHORT=$(echo "$NEW_NAME" | cut -d. -f1)

  OLDSUFFIX=$(echo "$OLD_NAME" | cut -d. -f2-)
  NEWSUFFIX=$(echo "$NEW_NAME" | cut -d. -f2-)

  echo ""
  echo "Setting hostname to: $NEW_NAME"
  echo "  and domainname to: $NEWSUFFIX"
  echo "  previous hostname: $OLD_NAME"
  echo ""

  hostname "$NEW_NAME"

  for file in /etc/hosts /etc/resolv.conf /etc/sysconfig/network /etc/hostname /etc/postfix/main.cf /etc/postfix/mydomains ; do
    if [ -e $file ] ; then
      sed -i.old "s/$OLD_NAME/$NEW_NAME/g" $file
      sed -i.old "s/$OLDSUFFIX/$NEWSUFFIX/g" $file
      sed -i.old "s/$OLDSHORT/$NEWSHORT/g" $file
      echo "edited $file"
    fi
  done

  echo ""
  echo "If binary logging enabled or host declared in mysql, we will need to fix"
  echo ""
  echo "################################################################################"
fi
}


rack_user() {
  echo "################################################################################"
  id rack
  if [ $? -eq 0 ] ; then
    echo "It looks like there is a rack user already"
  else
    echo "adding Rack user"
    useradd -m rack
  fi
  echo ""
  echo "be sure to manually set the root and rack passwords based on core"
  echo ""
  echo "################################################################################"
}

make_cookies() {
  echo "################################################################################"
  if [[ -d /root/.rackspace ]] ; then
    echo ""
    echo "moving old /root/.rackspace directory to /root/.rackspace.$(date +%F_%R)"
    echo ""
    mv /root/.rackspace /root/.rackspace.$(date +%F_%R)
  fi

  echo "Creating cookies in /root/.rackspace directory"

  mkdir -p /root/.rackspace
  for c_is_for_cookie in kick_date public_ip customer_number datacenter primary_user segment server_number kick ; do
    echo "" > /root/.rackspace/$c_is_for_cookie
  done


  if [[ -n "$new_external_ip" ]] ; then
    echo "$new_external_ip" > /root/.rackspace/public_ip
  else
    echo "new_external_ip variable not found. Nimbus probably won't install correctly"
  fi


  if [[ -n "$customer_number" ]] ; then
    echo "$customer_number" > /root/.rackspace/customer_number
  else
    echo "customer_number variable not found. populate /root/.rackspace/customer_number manually"
  fi

  if [[ -n "$datacenter" ]] ; then
    echo "$datacenter" > /root/.rackspace/datacenter
  else
    echo "datacenter variable not found. populate /root/.rackspace/datacenter manually"
  fi

  if [[ -n "$primary_user" ]] ; then
    echo "$primary_user" > /root/.rackspace/primary_user
  else
    echo "fakeuser" > /root/.rackspace/primary_user
    echo "primary_user variable not found, set to fakeuser"
  fi

  if [[ -n "$segment" ]] ; then
    echo "$segment" > /root/.rackspace/segment
  else
    echo "managed" > /root/.rackspace/segment
    echo "segment variable not found, set to managed"
  fi

  if [[ -n "$server_number" ]] ; then
    echo "$server_number" > /root/.rackspace/server_number
  else
    echo "server_number variable not found. populate /root/.rackspace/server_number manually"
  fi

  if [ -f /etc/redhat-release ] ; then
    cat /etc/redhat-release > /root/.rackspace/kick
  elif [ -f /etc/lsb-release ] ; then
    awk -F = '/DISTRIB_DESCRIPTION/ {print $2}' /etc/lsb-release > /root/.rackspace/kick
  else
  echo "distro/version not found, populate /root/.rackspace/kick manually"
  fi
  echo "################################################################################"
}

rhel_registration() {
  echo "################################################################################"
  echo "RHEL Registration should be done manually"
  echo "################################################################################"
}

rhel_specific_pkgs() {
  echo "################################################################################"
  echo "Installing RHEL-specific packages"
  yum install --quiet -y pyxf86config vmware-tools-core authconfig krb5-workstation ntp openldap-clients samba4-common sssd sssd-tools glibc.i686 rs-tools rs-release
  echo ""
  echo "################################################################################"
}

vmware_tools() {
  echo "################################################################################"
  echo "VMware tools installation should be done manually"
  echo "################################################################################"
}

active_directory() {
  echo "################################################################################"
  echo "AD/LDAP should be done manually"
  echo "################################################################################"
}

snmp_config() {
  echo "################################################################################"
  echo "skipping SNMP config"
  echo "################################################################################"
}



nimbus_config() {
  echo "################################################################################"
  if [[ -n "$customer_number" ]] && [[ -n "$new_external_ip" ]] && [[ -n "$datacenter" ]] && [[ -n "$server_number" ]] && [[ -n "$nimbus_probes" ]] ; then
    if [ -d /opt/nimbus ] || [ -d /opt/nimsoft ]; then
      echo Previous Nimbus install detected,
      tar zcvf "nimbus-backup-$(date +%Y-%m-%d).tgz" /opt/nim* /etc/init.d/nimbus
      /opt/nim*/bin/inst_init.sh remove
      sleep 30
      rm -f /etc/init.d/nimbus
      rm -fR /opt/nim{bus,soft}
      rm -fR /root/.rackspace/*nimbus* /root/.rackspace/nimbus*
    fi
    cd /root/.rackspace
    wget http://rax.mirror.rackspace.com/segsupport/nimbusinstallers-current.tar.gz
    tar xvfz nimbusinstaller*
    cd nimbus-installer
    python nimbusinstaller.py -A "$customer_number" -I "$new_external_ip" -D "$datacenter" -S "$server_number" -P "$nimbus_probes"
    echo "Nimbus Installation successful"
  else
    echo ""
    echo "we don't have all the variables we need for Nimbus, skipping installation"
    echo ""
  fi
  echo "################################################################################"
}

cloud_monitoring() {
  echo "################################################################################"
  echo "skipping cloud monitoring installation"
  echo ""
  echo "################################################################################"
}

sophos_config () {
  echo "################################################################################"
  echo "Starting sophos install"
  cd /root/.rackspace
  wget http://rax.mirror.rackspace.com/segsupport/sophos/rs-sophosav-installer
  python rs-sophosav-installer
  echo ""
  echo "################################################################################"
}

exit_clean () {
  echo "You are done, review script output and ensure all steps completed"
}

# Start doing all the things:
pre_work
start
bkup_configs
ip_config
set_hostname
rack_user
make_cookies
rhel_registration
rhel_specific_pkgs
vmware_tools
active_directory
snmp_config
nimbus_config
cloud_monitoring
sophos_config
exit_clean
