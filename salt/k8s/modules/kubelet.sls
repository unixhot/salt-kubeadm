# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubernetes Node kubelet
#******************************************

include:
  - k8s.modules.init
  - k8s.modules.repo

kubelet-install:
  pkg.installed:
    - name: kubelet
    - version: {{ pillar['K8S_PKG_VERSION'] }}
    - require:
      - file: k8s-repo
  file.managed:
    - name: /etc/sysconfig/kubelet
    - source: salt://k8s/templates/kubelet/kubelet.sysconfig.template
    - user: root
    - group: root
    - mode: 644
  service.running:
    - name: kubelet
    - enable: True
    - watch:
      - file: kubelet-install 
