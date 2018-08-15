#!/bin/bash

HELP="

This script must be run with a configuration file:
######################################################################
#  Default config file: ~/IntenseConfig
#  hostname=          # new hostname, with coreID and all that crap
#  customer_number=   # numerical customer number from CORE
#  datacenter=        # ORD1, DFW1, LON3, etc.
#  primary_user=      # primary username from CORE
#  segment=           # managed or intensive
#  server_number=     # numerical server number from CORE
#  nimbus_uninstall=  # do we need to remove nimbus first? yes or no
#  change_ip=         # do we need to change the IP?
#  old_internal_ip=   # old internal IP
#  new_internal_ip=   # new internal IP
#  old_public_ip=     # old public IP
#  new_public_ip=     # the new public IP
#  new_external_ip=   # the new public IP
#  public_iface=      # the nterface used for pubnet, probably eth0
#  internal_iface=    # the interface used for internal networking
#  destination_vm=    # if this is going to a VM put yes, otherwise no
#  vmware_tools=      # if yes, install vmware tools
#
#  example:
#  hostname=12345-fluffy_bunnies.woodchipper.co.uk.wtf.bbq
#
#   DO NOT PUT ANY SPACES OR EXTRA '=' SYMBOLS !!
#
######################################################################

This script must be run as ROOT. There is no support for sudo.

These are the steps we take:
start
  checking that we are root and we have our config file
bkup_configs
  backup current /etc/hosts and similar files
ip_config
  WIP - but will set public/private IP
set_hostname
  set hostname in system files, check mysql for possible related issues
rack_user
  create a rack user if one does not exist. You need to manually set passwd
make_cookies
  create the base files that other Rackspace applications need, like coreID
rhel_regestration
  If RHEL, then check regestration or register with RS. WIP
vmware_tools
  if vmware VM, install vmware_tools
active_directory
  WIP
snmp_config
  Installs SNMP. Ideally configure but not if VM WIP
rhel_specific_pkgs
  Installs net-tools, this is needed by other rackspace applications
  WIP but should consider other applications like screen
nimbus_config
  Will remove Nimbus if nimbus_uninstall=yes, and install Numbus fresh.
cloud_monitoring
  WIP but might not be needed
sophos_config
  WIP but might not be needed

Check https://one.rackspace.com/pages/viewpage.action?pageId=318505563
  That wiki is a better 'source of truth' than this script is

NOTE: typeclip does not play well with doublequotes. Use single quotes where possible.


"


start() {
  if [ -f ~/IntenseConfig ] ; then
    ## We have to run as root, this will make sure we do.
    ## This also ensures we have the config file
    if [ "$EUID" -ne 0 ] ; then
      echo "$HELP"
      echo "I wasn't kidding about being root"
      exit
    fi
    logger "Starting automation to raxify/instensify this server"
  else
    ## If we can't find the config file
    ## support for whateveer filename would be good, but not writing that ATM
    echo "$HELP"
    echo "I don't understand any config file not named ~/IntenseConfig, make it"
    exit
  fi
}


bkup_configs() {
  echo "backing up files before any edits, resolv.conf,hosts,etc."
  logger "backing up files before any edits, resolv.conf,hosts,etc."
  if [ -d /root/pre-intensification-backup/hosts.pre ] ; then
    mv /root/pre-intensification-backup /root/pre-intensification-backup.bak2
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
}


ip_config(){
  # https://rbgeek.wordpress.com/2014/09/16/ip-setting-on-centos6-using-shell-script/
  IP_GO_OR_NOGO=$(awk -F = '/change_ip/ {print $2}' ~/IntenseConfig)
  if [ "$IP_GO_OR_NOGO" == "yes" ] ; then
    logger "We will be changing the IP addresses"
    echo "Ummm, IDK pretend we do stuff here"
  elif [ "$IP_GO_OR_NOGO" == "no" ] ; then
    echo "we are not changing any IPs right now"
  else
    echo "Not changing IPs because change_ip parameter missing from config"
  fi
}


set_hostname() {
## https://one.rackspace.com/display/Linux/Changing+the+Hostname+on+Linux
  echo "preparing to set hostname"
  NEW_NAME=$(awk -F = '/hostname/ {print $2}' ~/IntenseConfig)
  OLD_NAME=$(hostname)

if [[ -n "$NEW_NAME" ]] ; then

  OLDSHORT=$(echo "$OLD_NAME" | cut -d. -f1)
  NEWSHORT=$(echo "$NEW_NAME" | cut -d. -f1)

  OLDSUFFIX=$(echo "$OLD_NAME" | cut -d. -f2-)
  NEWSUFFIX=$(echo "$NEW_NAME" | cut -d. -f2-)

  echo "Setting hostname to: $NEW_NAME"
  echo "  and domainname to: $NEWSUFFIX"
  echo "  previous hostname: $OLD_NAME"

  hostname "$NEW_NAME"

  for file in /etc/hosts /etc/resolv.conf /etc/sysconfig/network /etc/hostname /etc/postfix/main.cf /etc/postfix/mydomains ; do
    if [ -e $file ] ; then
      sed -i.old "s/$OLD_NAME/$NEW_NAME/g" $file
      sed -i.old "s/$OLDSUFFIX/$NEWSUFFIX/g" $file
      sed -i.old "s/$OLDSHORT/$NEWSHORT/g" $file
      echo "edited $file"
    fi
  done

### This needs fixing
#  if $(egrep "myhostname[ ]?=|mynetworks[ ]?=" /etc/postfix/main.cf) ; then
#    echo "Postfix probably needs more attention"

    postmap /etc/postfix/mydomains

  [[ -f /etc/syslog.conf ]] && service syslog restart
  [[ -f /etc/rsyslog.conf ]] && service rsyslog restart

  mysql -e "SELECT DISTINCT host FROM mysql.user;"
  echo "If the old hostname is listed above, we need to fix mysql"

  egrep 'log-bin|relay-log' /etc/my.cnf /etc/mysql/my.cnf
  echo "If binary logging enabled, we will need to fix mysql"

else
  echo "$HELP"
  echo "no hostname found in config, please fix"
  exit
fi
}


### Need to fix
rack_user() {
  id rack
  if [ $? -eq 0 ] ; then
    echo "It looks like there is a rack user already"
  else
    useradd -m rack
  fi
## RHEL/CentOS let you use a --stdin flag on passwd, we should enable that
  echo "be sure to manually set the root and rack passwords based on core"
}

make_cookies() {
## https://one.rackspace.com/display/Linux/Kick+Cookies
  mkdir -p /root/.rackspace

  date > /root/.rackspace/kick_date

  new_external_ip=$(awk -F = '/new_external_ip/ {print $2}' ~/IntenseConfig)
  if [[ -n "$new_external_ip" ]] ; then
    echo "$new_external_ip" > /root/.rackspace/public_ip
  else
    echo "new_external_ip variable not found. Nimbus probably won't install correctly"
  fi

  customer_number=$(awk -F = '/customer_number/ {print $2}' ~/IntenseConfig)
  if [[ -n "$customer_number" ]] ; then
    echo "$customer_number" > /root/.rackspace/customer_number
  else
    echo "customer_number variable not found. populate /root/.rackspace/customer_number manually"
  fi

  datacenter=$(awk -F = '/datacenter/ {print $2}' ~/IntenseConfig)
  if [[ -n "$datacenter" ]] ; then
    echo "$datacenter" > /root/.rackspace/datacenter
  else
    echo "datacenter variable not found. populate /root/.rackspace/datacenter manually"
  fi

  primary_user=$(awk -F = '/primary_user/ {print $2}' ~/IntenseConfig)
  if [[ -n "$primary_user" ]] ; then
    echo "$primary_user" > /root/.rackspace/primary_user
  else
    echo "fakeuser" > /root/.rackspace/primary_user
    echo "primary_user variable not found, set to fakeuser"
  fi

  segment=$(awk -F = '/segment/ {print $2}' ~/IntenseConfig)
  if [[ -n "$segment" ]] ; then
    echo "$segment" > /root/.rackspace/segment
  else
    echo "managed" > /root/.rackspace/segment
    echo "segment variable not found, set to managed"
  fi

  server_number=$(awk -F = '/server_number/ {print $2}' ~/IntenseConfig)
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
}

rhel_registration() {
  # https://one.rackspace.com/display/SegSup/RHN+Registration

# wget http://dfw.rhn.rackspace.com/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm
# yum -y --nogpgcheck localinstall rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm

# Visit: https://api.rhn.rackspace.com/cgi-bin/api/api.cgi?debug=1&device=<device#> (see note below for auth info). The device number is the core device number being registered. The output will contain an rhnreg_ks command to copy and execute on the server.
# Get password here: https://portal.rhn.rackspace.com/OTP

# yum -y --nogpgcheck install rs-tools rs-release
# rpm --import /etc/pki/rpm-gpg/RACKSPACE-GPG-KEY
# rpm --import /etc/pki/rpm-gpg/IUS-RHN-GPG-KEY

  echo "I don't know how to handle RHEL registration ATM"
}

vmware_tools() {
  # https://one.rackspace.com/display/VMWARE/Virtual+Machine+-+Install+VMWare+Tools+on+Linux
  # https://one.rackspace.com/display/VMWARE/Needs+updating+-+Virtual+Machine+-+Install+VMWare+Tools+on+Linux#Needsupdating-VirtualMachine-InstallVMWareToolsonLinux-RHEL5/CentOS5
  yum -y remove vmware* && yum -y remove vmware-open*
  mv /etc/yum.repos.d/vmware-tools.repo /etc/yum.repos.d/vmware-tools.repo.bak
  rm -rf /etc/vmware*; rm -rf /usr/lib/vmware*; rm -f /usr/bin/vmware*
  echo '[vmware-tools]' > /etc/yum.repos.d/vmware-tools.repo
  echo 'name=VMware Tools' >> /etc/yum.repos.d/vmware-tools.repo
  echo 'baseurl=http://packages.vmware.com/tools/esx/5.5u2/rhel6/x86_64' >> /etc/yum.repos.d/vmware-tools.repo
  echo 'enabled=1' >> /etc/yum.repos.d/vmware-tools.repo
  echo 'gpgcheck=1' >> /etc/yum.repos.d/vmware-tools.repo
  echo 'gpgkey=http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub' >> /etc/yum.repos.d/vmware-tools.repo

#[vmware-tools]
#name=VMware Tools
#baseurl=http://packages.vmware.com/tools/esx/5.5u2/rhel6/x86_64
#enabled=1
#gpgcheck=1
#gpgkey=http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub

  yum --enablerepo=vmware-tools clean metadata

  ## RHEL7 - yum install open-vm-tools-devel

  yum install -y pyxf86config; yum install -y vmware-tools-core vmware-tools-esx-kmods vmware-tools-esx-nox authconfig krb5-workstation ntp openldap-clients samba4-common sssd sssd-tools
}

active_directory() {
  # https://one.rackspace.com/display/Linux/AD+on+Linux+-+sssd-ad
  # https://one.rackspace.com/display/Linux/Authenticating+RHEL5+and+Ubuntu+Servers+with+eDirectory+LDAP#AuthenticatingRHEL5andUbuntuServerswitheDirectoryLDAP-ForRHEL5

# host -t SRV _ldap._tcp.LON.INTENSIVE.INT.
# host -t SRV _kerberos._tcp.LON.INTENSIVE.INT.
# host -t SRV _gc._tcp.INTENSIVE.INT.

# yum install authconfig krb5-workstation ntp openldap-clients samba4-common sssd sssd-tools libipa_hbac-devel.i686 libipa_hbac-devel.x86_64 --skip-broken

# service sssd stop

# chkconfig ntpd on; chkconfig nslcd off; chkconfig winbind off; chkconfig nscd off

# cp /etc/samba/smb.conf /etc/samba/smb.conf.bak2

# Jesus Christ this takes forever . . .


  echo "I don't know how to handle AD/LDAP"
}

snmp_config() {
  # https://one.rackspace.com/pages/viewpage.action?title=SNMP&spaceKey=Linux
  if [ -f /etc/redhat-release ] ; then
    yum -y install net-snmp
  elif [ -f /etc/lsb-release ] ; then
    apt-get -y install snmpd snmp-mibs-downloader
  fi
  echo "snmp should now be installed, further configuration is needed"
}

rhel_specific_pkgs(){
  if [ -f /etc/redhat-release ] ; then
    yum -y remove rs-rhntools-checkupdate
    yum install -y -q -e 0 net-tools
    # yum -y install net-tools
  else
    echo "you might need to manually install net-tools"
  fi
}

nimbus_config (){
## https://one.rackspace.com/display/enterprisesupport/Uninstalling+Nimbus+from+Linux
nimbus_uninstall=$(awk -F = '/nimbus_uninstall/ {print $2}' ~/IntenseConfig)
  if [[ "$nimbus_uninstall" == "yes" ]] ; then
    tar zcvf "nimbus-backup-$(date +%Y-%m-%d).tgz" /opt/nim* /etc/init.d/nimbus
    /opt/nim*/bin/inst_init.sh remove
    sleep 30
    rm -f /etc/init.d/nimbus
    rm -fR /opt/nim{bus,soft}
    rm -fR /root/.rackspace/*nimbus* /root/.rackspace/nimbus*
  fi
## https://one.rackspace.com/display/enterprisesupport/Linux+Installation+-+Nimbus
  cd /root/.rackspace
  wget http://rax.mirror.rackspace.com/segsupport/nimbusinstallers-current.tar.gz
  tar xvfz nimbusinstaller*
  cd nimbus-installer
## https://one.rackspace.com/display/~bria7739/Forcing+deployment+of+Nimbus+default+configuration
  python nimbusinstaller.py -A "$customer_number" -I "$new_external_ip" -D "$datacenter" -S "$server_number" -P ManagedProbes
  echo "other Numbus probes may be needed"
}

cloud_monitoring () {
  # https://github.rackspace.com/IAW/Monitoring-Agent-Installer
  echo "IDK if we need to worry about this"
}

sophos_config () {
  # https://one.rackspace.com/display/SegSup/Sophos+Linux+Installation

}

# Start doing all the things:
start
bkup_configs
ip_config
set_hostname
rack_user
make_cookies
rhel_regestration
#vmware_tools
active_directory
snmp_config
rhel_specific_pkgs
nimbus_config
cloud_monitoring
sophos_config
