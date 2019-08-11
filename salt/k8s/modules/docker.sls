# -*- coding: utf-8 -*-
#******************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Docker Install
#******************************************

docker-install:
  file.managed:
    - name: /etc/yum.repos.d/docker-ce.repo
    - source: salt://k8s/templates/docker/docker-ce.repo.template
    - user: root
    - group: root
    - mode: 644
  pkg.installed:
    - pkgs:
      - docker-ce-18.09.7-3.el7
      - docker-ce-cli-18.09.7

docker-daemon-config:
  file.managed:
    - name: /etc/docker/daemon.json
    - source: salt://k8s/templates/docker/daemon.json.template
    - user: root
    - group: root
    - mode: 644

docker-service:
  service.running:
    - name: docker
    - enable: True
    - watch:
      - file: docker-daemon-config
