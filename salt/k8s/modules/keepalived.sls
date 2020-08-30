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

keepalived-health-config:
  file.managed:
    - name: /etc/keepalived/haproxy_health_check.sh
    - source: salt://k8s/templates/keepalived/haproxy_health_check.sh
    - user: root
    - group: root
    - mode: 755

keepalived-config:
  file.managed:
    - name: /etc/keepalived/keepalived.conf
    - source: salt://k8s/templates/keepalived/keepalived.conf.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_VIP: {{ pillar['MASTER_VIP'] }}
    - require:
      - pkg: keepalived-install

keepalived-service:
  service.running:
    - name: keepalived
    - enable: True
    - reload: True
    - wathch:
      - file: keepalived-config
