# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubeadm init YAML
#******************************************

include:
  - k8s.modules.repo

haproxy-install:
  pkg.installed:
    - name: haproxy
    - require:
      - file: k8s-repo

haproxy-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://k8s/templates/haproxy/haproxy.cfg.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_VIP: {{ pillar['MASTER_VIP'] }}
    - require:
      - pkg: haproxy-install

haproxy-service:
  service.running:
    - name: haproxy
    - enable: True
    - reload: True
    - wathch:
      - file: haproxy-config
