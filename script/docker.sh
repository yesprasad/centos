#!/bin/bash

if [[ ! "$DOCKER" =~ ^(true|yes|on|1|TRUE|YES|ON])$ ]]; then
  exit
fi

echo "==> Run the Docker installation script"
curl -sSL https://get.docker.com | sh

echo "==> Create the docker group"
# Add the docker group if it doesn't already exist
groupadd docker

echo "==> Add the connected "${USER}" to the docker group."
gpasswd -a ${USER} docker
gpasswd -a ${SSH_USERNAME} docker

echo "==> Starting docker"
service docker start
echo "==> Enabling docker to start on reboot"
chkconfig docker on

cd /tmp
wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
chmod a+x /tmp/jq-linux64
mv /tmp/jq-linux64 /usr/local/bin/jq
wget https://github.com/SvenDowideit/generate_cert/releases/download/0.2/generate_cert-0.2-linux-amd64
chmod a+x /tmp/generate_cert-0.2-linux-amd64
mv /tmp/generate_cert-0.2-linux-amd64 /usr/local/bin/generate_cert

mkdir -p /var/lib/boot2docker/tls
chmod 700 /var/lib/boot2docker/tls
mkdir -p /usr/local/src/docker
cat <<_EOF_ | cat > /usr/local/src/docker/docker-init.sh
CERTDIR=/var/lib/boot2docker/tls/
CERT_INTERFACES='eth0'
CACERT="\${CERTDIR}ca.pem"
CAKEY="\${CERTDIR}cakey.pem"
SERVERCERT="\${CERTDIR}server.pem"
SERVERKEY="\${CERTDIR}serverkey.pem"
CERT="\${CERTDIR}cert.pem"
KEY="\${CERTDIR}key.pem"
ORG=Boot2Docker
SERVERORG="\${ORG}"
CAORG="\${ORG}CA"
CERTHOSTNAMES="\$(hostname -s)"
date -s 'yesterday'
for interface in \${CERT_INTERFACES}; do
  IPS=\$(ip addr show \${interface} |sed -nEe 's/^[ \t]*inet[ \t]*([0-9.]+)\/.*\$/\1/p')
  for ip in \$IPS; do
    CERTHOSTNAMES="\$CERTHOSTNAMES,\$ip"
  done
done
echo "Generating CA cert"
/usr/local/bin/generate_cert --cert="\$CACERT" --key="\$CAKEY" --org="\$CAORG" 2>&1
echo "Generate server cert"
/usr/local/bin/generate_cert --host="\$CERTHOSTNAMES" --ca="\$CACERT" --ca-key="\$CAKEY" --cert="\$SERVERCERT" --key="\$SERVERKEY" --org="\$SERVERORG" 2>&1
echo "\$CERTHOSTNAMES" > "\$CERTDIR/hostnames"
echo "Generating client cert"
/usr/local/bin/generate_cert --ca="\$CACERT" --ca-key="\$CAKEY" --cert="\$CERT" --key="\$KEY" --org="\$ORG" >/dev/null 2>&1
USERCFG="/home/vagrant/.docker"
mkdir -p "\$USERCFG"
chmod 700 "\$USERCFG"
cp "\$CACERT" "\$USERCFG"
cp "\$CERT" "\$USERCFG"
cp "\$KEY" "\$USERCFG"
chown -R vagrant:vagrant "\$USERCFG"

echo "Generating Dockerhost file"
mkdir -p /dockerhost
chmod 755 /dockerhost
/usr/local/bin/jq -n \
--arg hostname \$(hostname -s) \
--arg fqdn \$(hostname) \
--arg eipaddr \$(ifconfig eth0|grep -Po 'inet \K[\d.]+') \
--arg dipaddr 172.17.0.1 \
--arg iamToken missing \
--arg congoEnvironment dev \
'{"hostname":\$hostname, "fqdn":\$fqdn, "externalIp":\$eipaddr, "dockerIp":\$dipaddr, "elkRedisBroker":\$dipaddr, "iamToken": \$iamToken,"congoEnvironment": \$congoEnvironment}' \
> /dockerhost/hostinfo.json
echo "Starting Docker"
service docker restart >/dev/null 2>&1
echo "Docker Started"
_EOF_
chmod 755 /usr/local/src/docker/docker-init.sh

cat <<_EOF_ | cat > /usr/local/src/docker/docker-reboot.sh
/usr/local/bin/jq -n \
--arg hostname \$(hostname -s) \
--arg fqdn \$(hostname) \
--arg eipaddr \$(ifconfig eth0|grep -Po 'inet \K[\d.]+') \
--arg dipaddr \$(ifconfig docker0|grep -Po 'inet \K[\d.]+') \
--arg iamToken missing \
--arg congoEnvironment dev \
'{"hostname":\$hostname, "fqdn":\$fqdn, "externalIp":\$eipaddr, "dockerIp":\$dipaddr, "elkRedisBroker":\$dipaddr, "iamToken": \$iamToken,"congoEnvironment": \$congoEnvironment}' \
> /dockerhost/hostinfo.json
_EOF_
chmod 755 /usr/local/src/docker/docker-reboot.sh

cat <<_EOF_ | cat > /etc/sysconfig/docker
OPTIONS="-H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/var/lib/boot2docker/tls/ca.pem --tlscert=/var/lib/boot2docker/tls/server.pem --tlskey=/var/lib/boot2docker/tls/serverkey.pem --dns=172.17.0.1"
_EOF_

cat <<_EOF_ | cat > /usr/lib/systemd/system/docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
_EOF_

cat <<_EOF_ | cat > /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target network.target
Requires=docker.socket

[Service]
EnvironmentFile=-/etc/sysconfig/docker
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// \$OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
ExecStartPost=/bin/bash /usr/local/src/docker/docker-reboot.sh
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
_EOF_


# Setup DNSMASQ for more vpn-friendly DNS resolution
# systemctl restart NetworkManager
yum install -y dnsmasq

cat <<_EOF_ | cat > /etc/NetworkManager/NetworkManager.conf
[main]
dns=dnsmasq
_EOF_

cat <<_EOF_ | cat > /etc/NetworkManager/dnsmasq.d/cdk.conf
addn-hosts=/usr/local/etc/dnsmasq.hosts/
server=/cdk.com/139.126.16.198
server=/salesforce.com/139.126.16.198
server=/force.com/139.126.16.198
server=/adp.com/139.126.16.198
server=/adpedge.com/139.126.16.198
server=/dsghost.net/139.126.16.198
address=/.dev/127.0.0.1
_EOF_
cat <<_EOF_ | cat > /etc/NetworkManager/dnsmasq.d/listen.conf
listen-address=172.17.0.1
_EOF_