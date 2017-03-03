#!/bin/bash

if [[ ! "$DOCKER" =~ ^(true|yes|on|1|TRUE|YES|ON])$ ]]; then
  exit
fi

yum -y install unzip bind-utils
cd /tmp
wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip
unzip consul_0.6.4_linux_amd64.zip
mv consul /usr/bin
rm -f /tmp/consul_0.6.4_linux_amd64.zip

cd /tmp
wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_web_ui.zip
mkdir -p /usr/share/consul
cd /usr/share/consul
unzip /tmp/consul_0.6.4_web_ui.zip
rm -f /tmp/consul_0.6.4_web_ui.zip

echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
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

cat <<_EOF_ | cat > /etc/consul.d/ns-text-connect-docker-engine.json
{
    "service": {
        "name": "ns-text-connect-docker-engine",
        "id": "ns-text-connect-docker-engine",
        "tags": [ "docker-engine", "textconnect"],
        "checks": [
            {
                "id": "docker-health",
                "script": "/opt/textconnect/docker-engine/docker-is-up.sh",
                "interval": "10s"
            },
            {
                "id": "docker-registrator",
                "script": "/opt/textconnect/docker-engine/registrator-is-up.sh",
                "interval": "10s"
            }
        ]
    }
}
_EOF_

mkdir -p /opt/textconnect/docker-engine/
wget -O /opt/textconnect/docker-engine/docker-is-up.sh https://gist.githubusercontent.com/joshrivers/0e333f8e2eaf21ea0135/raw/17f1a0a76c692134ea0cfbe8f8910b6b16ac3995/docker-is-up.sh
chmod 755 /opt/textconnect/docker-engine/docker-is-up.sh
wget -O /opt/textconnect/docker-engine/registrator-is-up.sh https://gist.githubusercontent.com/joshrivers/66452e8685dd2294877c/raw/6c48dd97065920b069a37844cef92a362991ef56/registrator-is-up.sh
chmod 755 /opt/textconnect/docker-engine/registrator-is-up.sh

cd /tmp
wget https://github.com/CiscoCloud/consul-cli/releases/download/v0.3.1/consul-cli_0.3.1_linux_amd64.tar.gz
tar xfvz consul-cli_0.3.1_linux_amd64.tar.gz
mv consul-cli_0.3.1_linux_amd64/consul-cli /usr/bin
rm -f /tmp/consul-cli_0.3.1_linux_amd64.tar.gz

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


