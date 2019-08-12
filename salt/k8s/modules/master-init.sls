# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubeadm Master init YAML
#******************************************

master-init:
  cmd.run:
    - name: kubeadm init --config /etc/sysconfig/kubeadm.yml --ignore-preflight-errors=Swap,NumCPU
    - unless: test -f /etc/kubernetes/admin.conf
