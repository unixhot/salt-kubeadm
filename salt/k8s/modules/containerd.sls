# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Docker Install
#******************************************

containerd-install:
  cmd.run:
    - name: dnf config-manager --add-repo=http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  pkg.installed:
    - name: containerd.io
      
containerd-config-dir:
  file.directory:
    - name: /etc/containerd
    
containerd-daemon-config:
  cmd.run:
    - name: containerd config default > /etc/containerd/config.toml && sed -i 's#k8s.gcr.io/pause#registry.aliyuncs.com/google_containers/pause#g' /etc/containerd/config.toml

crictl-config:
  file.managed:
    - name: /etc/crictl.yaml
    - source: salt://k8s/templates/containerd/crictl.yaml.template
    - user: root
    - group: root
    - mode: 644

containerd-service:
  service.running:
    - name: containerd
    - enable: True
    - watch:
      - file: containerd-daemon-config
