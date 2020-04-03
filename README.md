# SaltStack自动化部署Kubernetes(kubeadm版)

- 在Kubernetes v1.13版本开始，kubeadm正式可以生产使用，但是kubeadm手动操作依然很繁琐，这里使用SaltStack进行自动化部署。

## 版本明细：Release-v1.18.0

- 支持高可用HA
- 测试通过系统：CentOS 7.7
- salt-ssh:     2017.7.4
- kubernetes：  v1.18.0
- docker-ce:    18.09.7

> 注意：从Kubernetes 1.16版本中很多API名称发生了变化，例如常用的daemonsets, deployments, replicasets的API从extensions/v1beta1全部更改为apps/v1，所有老的YAML文件直接使用会有报错，请注意修改，详情可参考[Kubernetes 1.18 CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.18.md)

### 架构介绍
建议部署节点：最少三个节点，请配置好主机名解析（必备）
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.18.0，保证稳定性。

### 技术交流群（加群请备注来源于Github）：
- 云计算与容器架构师：252370310


# 部署手册

请参考开源书籍：[Docker和Kubernetes实践指南](http://k8s.unixhot.com) 第五章节内容。


## 1.系统初始化(必备)

1.1 设置主机名！！！
```
[root@linux-node1 ~]# cat /etc/hostname 
linux-node1.example.com

[root@linux-node2 ~]# cat /etc/hostname 
linux-node2.example.com

[root@linux-node3 ~]# cat /etc/hostname 
linux-node3.example.com

```
1.2 设置/etc/hosts保证主机名能够解析
```
[root@linux-node1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.56.11 linux-node1 linux-node1.example.com
192.168.56.12 linux-node2 linux-node2.example.com
192.168.56.13 linux-node3 linux-node3.example.com

```
1.3 关闭SELinux
```
[root@linux-node1 ~]# vim /etc/sysconfig/selinux
SELINUX=disabled #修改为disabled
```

1.4 关闭NetworkManager和防火墙开启自启动
```
[root@linux-node1 ~]# systemctl stop firewalld && systemctl disable firewalld
[root@linux-node1 ~]# systemctl stop NetworkManager && systemctl disable NetworkManager
```

## 2.安装Salt-SSH并克隆本项目代码。

2.1 设置部署节点到其它所有节点的SSH免密码登录（包括本机）
```bash
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```

2.2 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）
```
[root@linux-node1 ~]# yum install -y https://mirrors.aliyun.com/epel/epel-release-latest-7.noarch.rpm
[root@linux-node1 ~]# yum install -y https://mirrors.aliyun.com/saltstack/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
[root@linux-node1 ~]# sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
[root@linux-node1 ~]# yum install -y salt-ssh git unzip
```

2.3 获取本项目代码，并放置在/srv目录
```
[root@linux-node1 ~]# git clone https://github.com/unixhot/salt-kubeadm.git
[root@linux-node1 ~]# cd salt-kubeadm/
[root@linux-node1 ~]# mv * /srv/
[root@linux-node1 srv]# /bin/cp /srv/roster /etc/salt/roster
[root@linux-node1 srv]# /bin/cp /srv/master /etc/salt/master
```


## 3.Salt SSH管理的机器以及角色分配

- k8s-role: 用来设置K8S的角色

```
[root@linux-node1 ~]# vim /etc/salt/roster 
linux-node1:
  host: 192.168.56.11
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master

linux-node2:
  host: 192.168.56.12
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node

linux-node3:
  host: 192.168.56.13
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
```

## 4.修改对应的配置参数，本项目使用Salt Pillar保存配置
```
[root@linux-node1 ~]# vim /srv/pillar/k8s.sls
#设置需要安装的Kubernetes版本
K8S_VERSION: "1.18.0"

#设置Master的IP地址(必须修改)
MASTER_IP: "192.168.56.11"

#通过Grains FQDN自动获取本机IP地址，请注意保证主机名解析到本机IP地址
NODE_IP: {{ grains['fqdn_ip4'][0] }}

#配置Service IP地址段
SERVICE_CIDR: "10.1.0.0/16"

#Kubernetes服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_KUBERNETES_SVC_IP: "10.1.0.1"

#Kubernetes DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP: "10.1.0.2"

#设置Node Port的端口范围
NODE_PORT_RANGE: "20000-40000"

#设置POD的IP地址段
POD_CIDR: "10.2.0.0/16"

#设置集群的DNS域名
CLUSTER_DNS_DOMAIN: "cluster.local."

```

## 5.单Master集群部署

5.1 测试Salt SSH联通性
```
[root@linux-node1 ~]# salt-ssh '*' test.ping
```

5.2 部署K8S集群
执行高级状态，会根据定义的角色再对应的机器部署对应的服务
```
#保证机器没有SWAP分区，如果存在需要关闭，如果不是全新的系统，请谨慎执行关闭交换分区操作！
[root@linux-node1 ~]# swapoff -a
[root@linux-node1 ~]# salt-ssh '*' state.highstate
```

> 喝杯咖啡休息一下，根据网络环境的不同，该步骤一般时长在5分钟以内，如果执行有失败可以再次执行即可！执行该操作会部署基本的环境，包括初始化需要用到的YAML。

5.3 初始化Master节点
  
如果是在实验环境，只有1个CPU，并且虚拟机存在交换分区，在执行初始化的时候需要增加--ignore-preflight-errors=Swap,NumCPU。
```
# 你可以对kubeadm.yml进行定制，kubeadm会读取该文件进行初始化操作，这里我修改了负载均衡的配置使用IPVS
[root@linux-node1 ~]# vim /etc/sysconfig/kubeadm.yml
[root@linux-node1 ~]# kubeadm init --config /etc/sysconfig/kubeadm.yml --ignore-preflight-errors=Swap,NumCPU 
```
需要下载Kubernetes所有应用服务镜像，根据网络情况，时间可能较长，请等待。可以在新窗口，docker images查看下载镜像进度。
安装完毕后配置
```
[root@linux-node1 ~]# mkdir -p $HOME/.kube
[root@linux-node1 ~]# cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@linux-node1 ~]# chown $(id -u):$(id -g) $HOME/.kube/config
```

5.4 部署网络插件Flannel 

```
[root@linux-node1 ~]# kubectl create -f /etc/sysconfig/kube-flannel.yml 
```

> 在新版本的Flannel的YAML中增加CNI的版本， "cniVersion": "0.2.0",所以使用老的Flannel资源配置会有以下的报错。
```
Nov 15 12:30:19 k8s-node1 kubelet: E1115 12:30:19.825818    7637 kubelet.go:2187] Container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
Nov 15 12:30:24 k8s-node1 kubelet: W1115 12:30:24.123610    7637 cni.go:202] Error validating CNI config &{cbr0  false [0xc0003a1360 0xc0003a14c0] [123 10 32 32 34 110 97 109 101 34 58 32 34 99 98 114 48 34 44 10 32 32 34 112 108 117 103 105 110 115 34 58 32 91 10 32 32 32 32 123 10 32 32 32 32 32 32 34 116 121 112 101 34 58 32 34 102 108 97 110 110 101 108 34 44 10 32 32 32 32 32 32 34 100 101 108 101 103 97 116 101 34 58 32 123 10 32 32 32 32 32 32 32 32 34 104 97 105 114 112 105 110 77 111 100 101 34 58 32 116 114 117 101 44 10 32 32 32 32 32 32 32 32 34 105 115 68 101 102 97 117 108 116 71 97 116 101 119 97 121 34 58 32 116 114 117 101 10 32 32 32 32 32 32 125 10 32 32 32 32 125 44 10 32 32 32 32 123 10 32 32 32 32 32 32 34 116 121 112 101 34 58 32 34 112 111 114 116 109 97 112 34 44 10 32 32 32 32 32 32 34 99 97 112 97 98 105 108 105 116 105 101 115 34 58 32 123 10 32 32 32 32 32 32 32 32 34 112 111 114 116 77 97 112 112 105 110 103 115 34 58 32 116 114 117 101 10 32 32 32 32 32 32 125 10 32 32 32 32 125 10 32 32 93 10 125 10]}: [plugin flannel does not support config version ""]
Nov 15 12:30:24 k8s-node1 kubelet: W1115 12:30:24.123737    7637 cni.go:237] Unable to update cni config: no valid networks found in /etc/cni/net.d
```

5.5 节点加入集群

1. 在Master节点上输出加入集群的命令：
```
[root@linux-node1 ~]# kubeadm token create --print-join-command
kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611 
```

2. 在Node节点上执行上面输出的命令，进行部署并加入集群。
```
#linux-node2.example.com
[root@linux-node2 ~]# swapoff -a
[root@linux-node2 ~]# kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611

#linux-node3.example.com
[root@linux-node3 ~]# swapoff -a
[root@linux-node3 ~]# kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611
```

## 6.测试Kubernetes安装

### 查看组件状态

```
[root@linux-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
```

### 查看节点状态
```
[root@linux-node1 ~]# kubectl get node
NAME            STATUS    ROLES     AGE       VERSION
192.168.56.11   Ready     master    1m        v1.18.0
192.168.56.12   Ready     <none>    1m        v1.18.0
192.168.56.13   Ready     <none>    1m        v1.18.0
```

## 7.测试Kubernetes集群和Flannel网络

1. 创建Deployment测试
```
[root@linux-node1 ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000
deployment "net-test" created
需要等待拉取镜像，可能稍有的慢，请等待。
```

2. 查看创建状态
```
[root@linux-node1 ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-n9lvk   1/1       Running   0          14s       10.2.12.2   192.168.56.13
net-test-5767cb94df-zclc5   1/1       Running   0          14s       10.2.24.2   192.168.56.12
```

3. 测试联通性，如果都能ping通，说明Kubernetes集群部署完毕，有问题请QQ群交流。
```
[root@linux-node1 ~]# ping -c 1 10.2.12.2
PING 10.2.12.2 (10.2.12.2) 56(84) bytes of data.
64 bytes from 10.2.12.2: icmp_seq=1 ttl=61 time=8.72 ms

--- 10.2.12.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 8.729/8.729/8.729/0.000 ms

[root@linux-node1 ~]# ping -c 1 10.2.24.2
PING 10.2.24.2 (10.2.24.2) 56(84) bytes of data.
64 bytes from 10.2.24.2: icmp_seq=1 ttl=61 time=22.9 ms

--- 10.2.24.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 22.960/22.960/22.960/0.000 ms
```

# 必备插件

## 1. 部署Ingress-Control

```
[root@linux-node1 ~]# kubectl get node
NAME                      STATUS   ROLES    AGE    VERSION
linux-node1.example.com   Ready    master   120m   v1.17.3
linux-node2.example.com   Ready    <none>   113m   v1.17.3
linux-node3.example.com   Ready    <none>   108m   v1.17.3

[root@linux-node1 ~]# kubectl label nodes linux-node2.example.com edgenode=true


[root@linux-node1 ~]# kubectl create -f ingress-nginx.yaml 
[root@linux-node1 ~]# kubectl get pod -n ingress-nginx
NAME                             READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-8nknv   1/1     Running   0          55s
```


## 2.部署Helm 3.0

> HELM是Kubernetes的包管理工具。使用Helm可以快速的安装和部署应用到Kubernetes上。

1.部署Helm
```
[root@linux-node1 ~]# cd /usr/local/src
[root@linux-node1 src]# wget https://get.helm.sh/helm-v3.1.0-linux-amd64.tar.gz
[root@linux-node1 src]# tar zxf helm-v3.1.0-linux-amd64.tar.gz
[root@linux-node1 src]# mv linux-amd64/helm /usr/local/bin/
```

2.验证安装是否成功
```
[root@linux-node1 ~]# helm version
version.BuildInfo{Version:"v3.1.0", GitCommit:"b29d20baf09943e134c2fa5e1e1cab3bf93315fa", GitTreeState:"clean", GoVersion:"go1.13.7"}

```

## 9.如何新增Kubernetes节点

1.设置SSH无密码登录
```
[root@linux-node1 ~]# ssh-copy-id linux-node3
```

2.在/etc/salt/roster里面，增加对应的机器
```
[root@linux-node1 ~]# vim /etc/salt/roster 
linux-node4:
  host: 192.168.56.14
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
```

3.执行SaltStack状态salt-ssh '*' state.highstate。
```
[root@linux-node1 ~]# salt-ssh 'linux-node4' state.highstate
```

## Kubernetes高可用多Master部署(待更新)
