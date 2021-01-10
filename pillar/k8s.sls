# -*- coding: utf-8 -*-
#********************************************
# Author:       Jason Zhao
# Email:        shundong.zhao@linuxhot.com
# Organization: http://www.devopsedu.com/
# Description:  Kubernetes Config with Pillar
#********************************************
#Kubernetes version
K8S_VERSION: "1.19.6"

#Kubernetes package version
K8S_PKG_VERSION: "1.19.6-0"

#for kubernetes cluster
MASTER_VIP: "192.168.56.10"

#Kubernetes Master IP
MASTER_IP: "192.168.56.11"

#Kubernetes Node IP
NODE_IP: {{ grains['fqdn_ip4'][0] }}


#Service CIDR
SERVICE_CIDR: "10.1.0.0/16"

#Kubernetes API Service Cluster IP
CLUSTER_KUBERNETES_SVC_IP: "10.1.0.1"

#Kubernetes DNS Service Cluster IP
CLUSTER_DNS_SVC_IP: "10.1.0.2"

#Node Port Range
NODE_PORT_RANGE: "20000-40000"

#Kubernetes Pod CIDR
POD_CIDR: "10.2.0.0/16"

#Kubernetes DNS Domain
CLUSTER_DNS_DOMAIN: "cluster.local."

#Docker Registry URL
DOCKER_REGISTRY: "http://192.168.56.11:5000"
