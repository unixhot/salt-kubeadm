# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubernetes repo
#******************************************

k8s-repo:
  file.managed:
    - name: /etc/yum.repos.d/kubernetes.repo
    - source: salt://k8s/templates/docker/kubernetes.repo.template
    - user: root
    - group: root
    - mode: 644
