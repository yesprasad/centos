#!/bin/bash

if [[ ! "$DOCKER" =~ ^(true|yes|on|1|TRUE|YES|ON])$ ]]; then
  exit
fi

yum -y install unzip
cd /tmp
wget https://releases.hashicorp.com/consul/0.6.3/consul_0.6.3_linux_amd64.zip
unzip consul_0.6.3_linux_amd64.zip
mv consul /usr/bin
rm -f /tmp/consul_0.6.3_linux_amd64.zip

cd /tmp
wget https://releases.hashicorp.com/consul/0.6.3/consul_0.6.3_web_ui.zip
mkdir -p /usr/share/consul
cd /usr/share/consul
unzip /tmp/consul_0.6.3_web_ui.zip
rm -f /tmp/consul_0.6.3_web_ui.zip

#echo consul agent   \& >> /etc/rc.d/rc.local
# echo consul agent -server -bootstrap -data-dir /tmp/consul -advertise=127.0.0.1 \& >> /etc/rc.d/rc.local
#chmod a+x /etc/rc.d/rc.local
mkdir -p /etc/consul.d

cat <<_EOF_ | cat > /etc/consul.d/consul.json
{
    "advertise_addr": "127.0.0.1",
    "client_addr": "0.0.0.0",
    "bootstrap": true,
    "server": true,
    "data_dir": "/tmp/consul",
    "log_level": "INFO",
    "datacenter": "dkr2",
    "ui_dir": "/usr/share/consul",
    "enable_syslog": true
}
_EOF_

cat <<_EOF_ | cat > /etc/systemd/system/consul.service
[Unit]
Description=Consul is a tool for service discovery and configuration. Consul is distributed, highly available, and extremely scalable.
Documentation=http://www.consul.io
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul
ExecStart=/usr/bin/consul \$CMD_OPTS
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
_EOF_

cat <<_EOF_ | cat >> /etc/sysconfig/consul
CMD_OPTS="agent -config-dir=/etc/consul.d -data-dir=/tmp/consul"
#GOMAXPROCS=4
_EOF_

systemctl enable consul


# echo "==> Run the Docker installation script"
# curl -sSL https://get.docker.com | sh

# echo "==> Create the docker group"
# # Add the docker group if it doesn't already exist
# groupadd docker

# echo "==> Add the connected "${USER}" to the docker group."
# gpasswd -a ${USER} docker
# gpasswd -a ${SSH_USERNAME} docker

# echo "==> Starting docker"
# service docker start
# echo "==> Enabling docker to start on reboot"
# chkconfig docker on
