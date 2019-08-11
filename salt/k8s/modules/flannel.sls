# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Flannel YAML
#******************************************
{% set flannel_version = "flannel-v0.10.0-linux-amd64" %}

flannel-etcd:
  file.managed:
    - name: /etc/sysconfig/kube-flannel.yml
    - source: salt://k8s/templates/flannel/kube-flannel.yml.template
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - defaults:
        POD_CIDR: {{ pillar['POD_CIDR'] }}
