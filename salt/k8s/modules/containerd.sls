# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Docker Install
#******************************************

containerd-install:
  file.managed:
    - name: /etc/yum.repos.d/docker-ce.repo
    - source: salt://k8s/templates/docker/docker-ce.repo.template
    - user: root
    - group: root
    - mode: 644
  pkg.installed:
    - name: containerd.io
    - version: 1.6.8-3.1.el7
      
containerd-config-dir:
  file.directory:
    - name: /etc/containerd
    
containerd-daemon-config:
  file.managed:
    - name: /etc/containerd/config.toml
    - source: salt://k8s/templates/containerd/config.toml.template
    - user: root
    - group: root
    - mode: 644

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
