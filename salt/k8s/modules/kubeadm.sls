# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubeadm init YAML
#******************************************

{% set k8s_version = "1.15.1" %}

include:
  - k8s.modules.repo

kubeadm-install:
  pkg.installed:
    - pkgs:
      - kubeadm-1.15.1
      - kubectl-1.15.1
    - require:
      - file: k8s-repo
  file.managed:
    - name: /etc/sysconfig/kubeadm.yml
    - source: salt://k8s/templates/kubeadm/kubeadm.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        SERVICE_CIDR: {{ pillar['SERVICE_CIDR'] }}  
        POD_CIDR: {{ pillar['POD_CIDR'] }}  
        MASTER_IP: {{ pillar['MASTER_IP'] }}  
