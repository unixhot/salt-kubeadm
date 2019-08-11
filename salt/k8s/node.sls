# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubernetes Node
#******************************************

include:
  - k8s.modules.docker
  - k8s.modules.repo
  - k8s.modules.init
  - k8s.modules.kubelet
  - k8s.modules.kubeadm
