#!/bin/bash
export http_proxy=http://ep.threatpulse.net:80
bin/box build centos72-docker parallels
vagrant box remove centos-docker
vagrant box add box/parallels/centos72-docker-nocm-2.0.12.box --name centos-docker
