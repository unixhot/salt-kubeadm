# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  NFS Install
#******************************************
nfs-data-dir:
  file.directory:
    - name: /opt/k8s-nfs

nfs-install:
  pkg.installed:
    - name: nfs-utils
  
  file.managed:
    - name: /etc/exports
    - source: salt://k8s/templates/nfs/nfs-exports.template
    - user: root
    - group: root
    - mode: 644
      
nfs-service:
  service.running:
    - name: nfs
    - enable: True
    - watch:
      - file: nfs-install
