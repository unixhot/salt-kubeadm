# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubernetes Master
#******************************************

include:
  - k8s.modules.docker
  - k8s.modules.repo
  - k8s.modules.init
  - k8s.modules.kubelet
  - k8s.modules.kubeadm
  - k8s.modules.flannel
  - k8s.modules.haproxy
  - k8s.modules.keepalived
