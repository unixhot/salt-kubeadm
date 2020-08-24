# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubeadm init YAML
#******************************************

include:
  - k8s.modules.repo

keepalived-install:
  pkg.installed:
    - name: keepalived
    - require:
      - file: k8s-repo

keepalived-config:
  file.managed:
    - name: /etc/keepalived/keepalived.conf
    - source: salt://k8s/templates/keepalived/keepalived.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP: {{ pillar['MASTER_IP'] }}
    - require:
      pkg: keepalived-install

keepalived-service:
  service.running:
    - name: keepalived
    - enable: True
    - reload: True
    - wathch:
      - file: keepalived-config
