#!/bin/sh

#
# Deploy a single VPN machine
# Fedora 29
#

###############################################################################
# VARIABLES
###############################################################################

MACHINE_HOSTNAME=$(hostname -f)

# DNS name of the Web Server
printf "DNS name of the Web Server [%s]: " "${MACHINE_HOSTNAME}"; read -r WEB_FQDN
WEB_FQDN=${WEB_FQDN:-${MACHINE_HOSTNAME}}

# DNS name of the OpenVPN Server (defaults to DNS name of the Web Server
# use different name if you want to allow moving the OpenVPN processes to 
# another machine in the future without breaking client configuration files
printf "DNS name of the OpenVPN Server [%s]: " "${WEB_FQDN}"; read -r VPN_FQDN
VPN_FQDN=${VPN_FQDN:-${WEB_FQDN}}

###############################################################################
# SYSTEM
###############################################################################

# SELinux enabled?

if ! /usr/sbin/selinuxenabled
then
    echo "Please **ENABLE** SELinux before running this script!"
    exit 1
fi

PACKAGE_MANAGER=/usr/bin/dnf

###############################################################################
# SOFTWARE
###############################################################################

# disable and stop existing firewalling
systemctl disable --now firewalld >/dev/null 2>/dev/null || true
systemctl disable --now iptables >/dev/null 2>/dev/null || true
systemctl disable --now ip6tables >/dev/null 2>/dev/null || true

# Add production RPM repository
curl -L -o /etc/yum.repos.d/LC.repo \
    https://repo.letsconnect-vpn.org/2/rpm/release/fedora/LC.repo

# install software (dependencies)
${PACKAGE_MANAGER} -y install mod_ssl php-opcache httpd iptables pwgen \
    iptables-services php-fpm php-cli policycoreutils-python chrony

# install additional language packs
# this is needed on Fedora, not on CentOS where they are all in glibc-common
${PACKAGE_MANAGER} -y install glibc-langpack-nl glibc-langpack-nb \
    glibc-langpack-da glibc-langpack-fr

# install software (VPN packages)
${PACKAGE_MANAGER} -y install vpn-server-node vpn-server-api \
    vpn-user-portal

###############################################################################
# SELINUX
###############################################################################

# allow Apache to connect to PHP-FPM
setsebool -P httpd_can_network_connect=1

# allow OpenVPN to bind to the management ports
semanage port -a -t openvpn_port_t -p tcp 11940-16036

# allow OpenVPN to bind to additional ports for client connections
semanage port -a -t openvpn_port_t -p tcp 1195-5290
semanage port -a -t openvpn_port_t -p udp 1195-5290

###############################################################################
# APACHE
###############################################################################

# Use a hardened ssl.conf instead of the default, gives A+ on
# https://www.ssllabs.com/ssltest/
cp resources/ssl.conf /etc/httpd/conf.d/ssl.conf
cp resources/localhost.centos.conf /etc/httpd/conf.d/localhost.conf

# VirtualHost
cp resources/vpn.example.centos.conf "/etc/httpd/conf.d/${WEB_FQDN}.conf"
sed -i "s/vpn.example/${WEB_FQDN}/" "/etc/httpd/conf.d/${WEB_FQDN}.conf"

###############################################################################
# PHP
###############################################################################

# set timezone to UTC
cp resources/70-timezone.ini /etc/php.d/70-timezone.ini
# session hardening
cp resources/75-session.fedora.ini /etc/php.d/75-session.ini

###############################################################################
# VPN-SERVER-API
###############################################################################

# update the IPv4 CIDR and IPv6 prefix to random IP ranges
vpn-server-api-update-ip --profile internet --host "${VPN_FQDN}"

# initialize the CA
sudo -u apache vpn-server-api-init

###############################################################################
# VPN-USER-PORTAL
###############################################################################

# DB init
sudo -u apache vpn-user-portal-init

###############################################################################
# NETWORK
###############################################################################

cat << EOF > /etc/sysctl.d/70-vpn.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# allow RA for IPv6 on external interface, NOT for static IPv6!
#net.ipv6.conf.eth0.accept_ra = 2
EOF

sysctl --system

###############################################################################
# UPDATE SECRETS
###############################################################################

# update API secret
vpn-server-api-update-api-secrets

###############################################################################
# CERTIFICATE
###############################################################################

# generate self signed certificate and key
openssl req \
    -nodes \
    -subj "/CN=${WEB_FQDN}" \
    -x509 \
    -sha256 \
    -newkey rsa:2048 \
    -keyout "/etc/pki/tls/private/${WEB_FQDN}.key" \
    -out "/etc/pki/tls/certs/${WEB_FQDN}.crt" \
    -days 90

###############################################################################
# WEB
###############################################################################

mkdir -p "/var/www/${WEB_FQDN}"
# Copy server info JSON file
cp resources/info.json "/var/www/${WEB_FQDN}/info.json"
sed -i "s/vpn.example/${WEB_FQDN}/" "/var/www/${WEB_FQDN}/info.json"

###############################################################################
# DAEMONS
###############################################################################

systemctl enable --now php-fpm
systemctl enable --now httpd

###############################################################################
# OPENVPN SERVER CONFIG
###############################################################################

# NOTE: the openvpn-server systemd unit file only allows 10 OpenVPN processes
# by default! 

# generate the OpenVPN server configuration files and certificates
vpn-server-node-server-config

# enable and start OpenVPN
systemctl enable --now openvpn-server@internet-0
systemctl enable --now openvpn-server@internet-1

###############################################################################
# FIREWALL
###############################################################################

# generate and install the firewall
vpn-server-node-generate-firewall --install

systemctl enable --now iptables
systemctl enable --now ip6tables

###############################################################################
# USERS
###############################################################################

REGULAR_USER="demo"
REGULAR_USER_PASS=$(pwgen 12 -n 1)

# the "admin" user is a special user, listed by ID to have access to "admin" 
# functionality in /etc/vpn-user-portal/config.php (adminUserIdList)
ADMIN_USER="admin"
ADMIN_USER_PASS=$(pwgen 12 -n 1)

sudo -u apache vpn-user-portal-add-user ${REGULAR_USER} "${REGULAR_USER_PASS}"
sudo -u apache vpn-user-portal-add-user ${ADMIN_USER}   "${ADMIN_USER_PASS}"

###############################################################################
# SHOW INFO
###############################################################################

echo "########################################################################"
echo "# Portal"
echo "#     https://${WEB_FQDN}/vpn-user-portal"
echo "#         Regular User: ${REGULAR_USER}"
echo "#         Regular User Pass: ${REGULAR_USER_PASS}"
echo "#"
echo "#         Admin User: ${ADMIN_USER}"
echo "#         Admin User Pass: ${ADMIN_USER_PASS}"
echo "########################################################################"
