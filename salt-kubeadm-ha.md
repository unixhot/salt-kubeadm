# SaltStack自动化部署Kubernetes(kubeadm HA版)

- 在Kubernetes v1.13版本开始，kubeadm正式可以生产使用，但是kubeadm手动操作依然很繁琐，这里使用SaltStack进行自动化部署。

## 版本明细：Release-v1.18.8

- 支持高可用HA
- 测试通过系统：CentOS 7.9
- salt-ssh:     3002.2
- kubernetes：  v1.18.8
- docker-ce:    19.03.8

> 注意：从Kubernetes 1.16版本开始很多API名称发生了变化，例如常用的daemonsets, deployments, replicasets的API从extensions/v1beta1全部更改为apps/v1，所有老的YAML文件直接使用会有报错，请注意修改，详情可参考[Kubernetes 1.18 CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.18.md)

### 架构介绍
建议部署节点：最少三个节点，请配置好主机名解析（必备）
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.18.8，保证稳定性。

### 技术交流群（加群请备注来源于Github）：
- 云计算与容器架构师：252370310


# 部署手册

请参考开源书籍：[Docker和Kubernetes实践指南](http://k8s.unixhot.com) 第五章节内容。


## 1.系统初始化(必备，所有节点都需操作)

**1.1 设置主机名！！！**

```
[root@linux-node1 ~]# vim /etc/hostname 
linux-node1.example.com

[root@linux-node2 ~]# vim /etc/hostname 
linux-node2.example.com

[root@linux-node3 ~]# vim /etc/hostname 
linux-node3.example.com

```
**1.2 设置/etc/hosts保证主机名能够解析**

```
[root@linux-node1 ~]# vim /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.56.11 linux-node1 linux-node1.example.com
192.168.56.12 linux-node2 linux-node2.example.com
192.168.56.13 linux-node3 linux-node3.example.com

```
**1.3 关闭SELinux**

```
[root@linux-node1 ~]# vim /etc/sysconfig/selinux
SELINUX=disabled #修改为disabled
```

**1.4 关闭NetworkManager和防火墙开启自启动**

```
[root@linux-node1 ~]# systemctl stop firewalld && systemctl disable firewalld
[root@linux-node1 ~]# systemctl stop NetworkManager && systemctl disable NetworkManager
```

**1.5 更新到最新版本并重启**

```
[root@linux-node1 ~]# yum update -y && reboot
```

> 注意：以上初始化操作需要所有节点都执行，缺少步骤会导致无法安装。


## 2.安装Salt-SSH并克隆本项目代码。

**2.1 设置部署节点到其它所有节点的SSH免密码登录（包括本机）**

```bash
[root@linux-node1 ~]# ssh-keygen -t rsa -q -N ''
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```

**2.2 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）**

```
[root@linux-node1 ~]# wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
[root@linux-node1 ~]# yum install -y https://repo.saltstack.com/py3/redhat/salt-py3-repo-latest.el7.noarch.rpm
[root@linux-node1 ~]# sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-py3-latest.repo
[root@linux-node1 ~]# yum install -y salt-ssh git unzip
```

**2.3 获取本项目代码，并放置在/srv目录**

```
[root@linux-node1 ~]# git clone https://github.com/unixhot/salt-kubeadm.git
[root@linux-node1 ~]# cd salt-kubeadm/
[root@linux-node1 ~]# cp -r * /srv/
[root@linux-node1 srv]# /bin/cp /srv/roster /etc/salt/roster
[root@linux-node1 srv]# /bin/cp /srv/master /etc/salt/master
```

## 3.Salt SSH管理的机器以及角色分配

> 注意：下方单Master部署和多Master部署，选择其中之一执行。

### Kubernetes单Master部署 

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

> k8s-role: 用来设置K8S的角色

### Kubernetes多Master部署

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
      k8s-role: master

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
K8S_VERSION: "1.18.8"

#设置软件包的版本，和安装版本有区别
K8S_PKG_VERSION: "1.18.8-0"

#设置高可用集群VIP地址（部署高可用必须修改）
MASTER_VIP: "192.168.56.10"

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

## 5.集群部署

### 5.1 测试Salt SSH联通性

```
[root@linux-node1 ~]# salt-ssh -i '*' -r 'yum install -y python3'
[root@linux-node1 ~]# salt-ssh -i '*' test.ping
linux-node2:
    True
linux-node3:
    True
linux-node1:
    True
```
> 保证没有问题，都返回True再继续。

### 5.2 部署K8S集群基础组件

执行高级状态，会根据定义的角色再对应的机器部署对应的服务
```
#保证机器没有SWAP分区，如果存在需要关闭，如果不是全新的系统，请谨慎执行关闭交换分区操作！
[root@linux-node1 ~]# salt-ssh '*' -r 'swapoff -a'
[root@linux-node1 ~]# salt-ssh '*' state.highstate
```

> 喝杯咖啡休息一下，根据网络环境的不同，该步骤一般时长在5分钟以内，如果执行有失败可以再次执行即可！执行该操作会部署基本的环境，包括初始化需要用到的YAML。执行完毕之后请查看结果，需要保证所有的Failed：为0，说明初始化成功。
```
Summary for linux-node3
-------------
Succeeded: 19 (changed=19)
Failed:     0
-------------
Total states run:     19
Total run time:  733.939 s
```

### 5.3 Master初始化

> 注意：下方单Master部署和多Master部署，选择其中之一执行。

1. 单Master初始化

在上面的操作中，是自动化安装了Kubeadm、kubelet、docker进行了系统初始化，并生成了后续需要的yaml文件，下面的操作手工操作用于了解kubeadm的基本知识。
如果是在实验环境，只有1个CPU，在执行初始化的时候需要增加--ignore-preflight-errors=NumCPU。
> 你可以对kubeadm.yml进行定制，kubeadm会读取该文件进行初始化操作，这里我修改了负载均衡的配置使用IPVS,存放在/etc/sysconfig/kubeadm.yml

```
[root@linux-node1 ~]# kubeadm init --config /etc/sysconfig/kubeadm.yml --ignore-preflight-errors=NumCPU 
```
> 需要下载Kubernetes所有应用服务镜像，根据网络情况，时间可能较长，请等待。可以在新窗口，docker images查看下载镜像进度。

2. 多Master初始化

```
[root@linux-node1 ~]# kubeadm init --config /etc/sysconfig/kubeadm-ha.yml --upload-certs --ignore-preflight-errors=NumCPU
```

### 5.4 为kubectl准备配置文件

kubectl默认会在用户的家目录寻找.kube/config配置文件，下面使用管理员的配置

```
[root@linux-node1 ~]# mkdir -p $HOME/.kube
[root@linux-node1 ~]# cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@linux-node1 ~]# chown $(id -u):$(id -g) $HOME/.kube/config
```
### 5.5 多集群控制节点添加

> 如果是多Master节点，需要将其它节点加入到集群中。非多Master请忽略本步骤。

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 192.168.56.10:8443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:e1faf2d489ff739544b3b46a5ced36a1e51b550b6d3ef9f8b29681bd1ae3bbb1 \
    --control-plane --certificate-key c725f2793006a655dc381e9ee4cb8bc9ab09d148ea8d54475e815c99f5ac2051

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.


### 5.6 部署网络插件Flannel

> 需要保证所有Node的网卡名称一直，如果你的网卡名称不是eth0，请修改对应参数。 - --iface=eth0，修改为对应的网卡名称。

```
[root@linux-node1 ~]# kubectl create -f /etc/sysconfig/kube-flannel.yml 
```

### 5.7 节点加入集群

1. 在Master节点上输出加入集群的命令：
```
[root@linux-node1 ~]# kubeadm token create --print-join-command
kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611 
```

2. 在Node节点上执行上面输出的命令，进行部署并加入集群。

> 如果执行的过程中，一直卡着无进度，请检查三台主机的时间是否同步，时间不同步会造成集群不正常，例如证书过期等。

**在linux-node2.example.com上执行**

```
[root@linux-node2 ~]# kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611
```

**在linux-node3.example.com上执行**
```
[root@linux-node3 ~]# kubeadm join 192.168.56.11:6443 --token qnlyhw.cr9n8jbpbkg94szj     --discovery-token-ca-cert-hash sha256:cca103afc0ad374093f3f76b2f91963ac72eabea3d379571e88d403fc7670611
```

## 6.测试Kubernetes安装

### 查看节点状态
```
[root@linux-node1 ~]# kubectl get node
NAME            STATUS    ROLES     AGE       VERSION
192.168.56.11   Ready     master    1m        v1.18.3
192.168.56.12   Ready     <none>    1m        v1.18.3
192.168.56.13   Ready     <none>    1m        v1.18.3
```

## 7.测试Kubernetes集群和Flannel网络

1. 创建Pod进行测试
```
[root@linux-node1 ~]# kubectl run net-test --image=alpine sleep 360000
deployment "net-test" created
需要等待拉取镜像，可能稍有的慢，请等待。
```

2. 查看创建状态
```
[root@linux-node1 ~]# kubectl get pod -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP         NODE                      NOMINATED NODE   READINESS GATES
net-test   1/1     Running   0          22s   10.2.12.2  linux-node2.example.com   <none>           <none>
```

3. 测试联通性，如果都能ping通，说明Kubernetes集群部署完毕。
```
[root@linux-node1 ~]# ping -c 1 10.2.12.2
PING 10.2.12.2 (10.2.12.2) 56(84) bytes of data.
64 bytes from 10.2.12.2: icmp_seq=1 ttl=61 time=8.72 ms

--- 10.2.12.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 8.729/8.729/8.729/0.000 ms
```

# 必备插件

## 1. 部署Ingress-Control

```
[root@linux-node1 ~]# kubectl get node
NAME                      STATUS   ROLES    AGE    VERSION
linux-node1.example.com   Ready    master   120m   v1.18.3
linux-node2.example.com   Ready    <none>   113m   v1.18.3
linux-node3.example.com   Ready    <none>   108m   v1.18.3

[root@linux-node1 ~]# kubectl label nodes linux-node2.example.com edgenode=true

[root@linux-node1 ~]# kubectl create -f /srv/addons/traefik-ingress/
```


## 2.部署Helm3

> HELM是Kubernetes的包管理工具。使用Helm可以快速的安装和部署应用到Kubernetes上。

1.部署Helm
```
[root@linux-node1 ~]# cd /usr/local/src
[root@linux-node1 src]# wget https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz
[root@linux-node1 src]# tar zxf helm-v3.2.4-linux-amd64.tar.gz
[root@linux-node1 src]# mv linux-amd64/helm /usr/local/bin/
```

2.验证安装是否成功
```
[root@linux-node1 ~]# helm version
version.BuildInfo{Version:"v3.2.4", GitCommit:"b29d20baf09943e134c2fa5e1e1cab3bf93315fa", GitTreeState:"clean", GoVersion:"go1.13.7"}

```

## 如何新增Kubernetes节点

1.设置SSH无密码登录
```
[root@linux-node1 ~]# ssh-copy-id linux-node4
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
