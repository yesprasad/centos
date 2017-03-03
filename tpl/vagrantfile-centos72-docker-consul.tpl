# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.provider "parallels" do |prl|
    prl.name = "Docker 17.03.0 with Consul on Centos 7.2"
  end
  config.vm.synced_folder "/Users", "/Users"

  config.vm.provision "shell",
    inline: "/usr/local/src/docker/docker-init.sh"
end
