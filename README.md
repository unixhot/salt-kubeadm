# SaltStack自动化部署Kubernetes(kubeadm HA版)

- 在Kubernetes v1.13版本开始，kubeadm正式可以生产使用，但是kubeadm手动操作依然很繁琐，这里使用SaltStack进行自动化部署。

## 版本明细：Release-v1.30.2

- 支持高可用HA
- 测试通过系统： CentOS 8.x（不再支持CentOS7）
- salt-ssh:    3002.2

### 架构介绍
建议部署节点：最少三个节点，请配置好主机名解析（必备）
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.30.2，保证稳定性。

# 部署手册

请参考开源书籍：[Docker和Kubernetes实践指南](http://k8s.unixhot.com) 第五章节内容。


## 1.系统初始化(必备，所有节点都需操作)

**1.1 设置主机名！！！**

```
[root@linux-node1 ~]# hostnamectl set-hostname linux-node1.example.com
[root@linux-node2 ~]# hostnamectl set-hostname linux-node2.example.com
[root@linux-node3 ~]# hostnamectl set-hostname linux-node3.example.com

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
```

**1.5 彻底关闭交换分区**
```
[root@linux-node1 ~]# vim /etc/fstab
#删除掉交换分区配置
```

**1.6 更新到最新版本并重启**

```
[root@linux-node1 ~]# yum update -y && reboot
```

> 注意：以上初始化操作需要所有节点都执行，缺少步骤会导致无法安装。Kubernetes要求集群的时间同步，并且主机名不能相同，而且保证可以解析。

## 2.安装Salt-SSH并克隆本项目代码。

**2.1 设置部署节点到其它所有节点的SSH免密码登录（包括本机）**

```
[root@linux-node1 ~]# ssh-keygen -t rsa -q -N ''
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```

**2.2 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）**

# For CentOS 8
```
rpm --import https://repo.saltproject.io/py3/redhat/8/x86_64/latest/SALTSTACK-GPG-KEY.pub
curl -fsSL https://repo.saltproject.io/py3/redhat/8/x86_64/latest.repo | sudo tee /etc/yum.repos.d/salt.repo
yum install -y salt-ssh git unzip
```

**2.3 获取本项目代码，并放置在/srv目录**

```
# 克隆项目
git clone https://github.com/unixhot/salt-kubeadm.git

# 放置文件
cd salt-kubeadm/
cp -r * /srv/
/bin/cp /srv/roster /etc/salt/roster
/bin/cp /srv/master /etc/salt/master
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

## 4.修改对应的配置参数，本项目使用Salt Pillar保存配置
```
[root@linux-node1 ~]# vim /srv/pillar/k8s.sls
#设置需要安装的Kubernetes版本
K8S_VERSION: "1.30.2"

#设置软件包的版本，和安装版本有区别
K8S_PKG_VERSION: "1.30.2-150500.1.1"

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
[root@linux-node1 ~]# salt-ssh -i '*' -r 'yum install -y python3 && swapoff -a'
[root@linux-node1 ~]# salt-ssh -i '*' test.ping
linux-node2:
    True
linux-node3:
    True
linux-node1:
    True
```
> 此步骤是测试salt-ssh可以联通待部署的节点，保证没有问题，都返回True方可继续，如果有异常请先解决异常。保证机器没有SWAP分区，如果存在需要关闭，如果不是全新的系统，请谨慎执行关闭交换分区操作！

### 5.2 部署K8S集群基础组件

执行高级状态，会根据定义的角色再对应的机器部署对应的服务，例如安装kubeadm、kubelet、docker，加载IPVS内核模板，调整内核参数，生成kubeadm的配置文件等。
```
salt-ssh '*' state.highstate
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
kubeadm init --config /etc/sysconfig/kubeadm.yml --ignore-preflight-errors=NumCPU 
```
> 需要下载Kubernetes所有应用服务镜像，根据网络情况，时间可能较长，请等待。可以在新窗口，docker images查看下载镜像进度。

### 5.4 为kubectl准备配置文件

kubectl默认会在用户的家目录寻找.kube/config配置文件，下面使用管理员的配置

```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.6 部署网络插件Flannel

> 需要保证所有Node的网卡名称一直，如果你的网卡名称不是eth0，请修改对应参数。 - --iface=eth0，修改为对应的网卡名称。

```
kubectl create -f /etc/sysconfig/kube-flannel.yml 
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
192.168.56.11   Ready     master    1m        v1.30.2
192.168.56.12   Ready     <none>    1m        v1.30.2
192.168.56.13   Ready     <none>    1m        v1.30.2
```
> 安装时，默认给linux-node1这个node设置了污点，默认不会调度非关键组件的Pod，如需取消污点，请执行kubectl taint  node linux-node1.example.com node-role.kubernetes.io/master:NoSchedule-

## 7.测试Kubernetes集群和Flannel网络

1. 创建Pod进行测试
```
[root@linux-node1 ~]# kubectl run nginx-test --image=registry.cn-beijing.aliyuncs.com/opsany/nginx:1.26-perl
pod/nginx-test created
需要等待拉取镜像，可能稍有的慢，请等待。
```

2. 查看创建状态
```
[root@linux-node1 ~]# kubectl get pod -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP         NODE                      NOMINATED NODE   READINESS GATES
nginx-test   1/1     Running   0          22s   10.2.12.2  linux-node2.example.com   <none>           <none>
```

3. 测试联通性，如果都能ping通，说明Kubernetes集群部署完毕。
```
[root@linux-node1 ~]# ping 10.2.12.2
PING 10.2.12.2 (10.2.12.2) 56(84) bytes of data.
64 bytes from 10.2.12.2: icmp_seq=1 ttl=61 time=8.72 ms

--- 10.2.12.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 8.729/8.729/8.729/0.000 ms
```

4. 测试访问，如果访问正常。说明Kubernetes集群运行正常。
```
[root@linux-node1 ~]# curl --head http://10.2.1.3
HTTP/1.1 200 OK
Server: nginx/1.26.1
Date: Mon, 17 Jun 2024 12:54:23 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 28 May 2024 13:28:07 GMT
Connection: keep-alive
ETag: "6655dbe7-267"
Accept-Ranges: bytes
```

# 必备插件

## 1. 部署Ingress-Control

```
kubectl label nodes linux-node2.example.com edgenode=true
kubectl create -f /srv/addons/nginx-ingress/nginx-ingress.yaml
kubectl get pod -n ingress-nginx
```

## 2.部署Helm3

> HELM是Kubernetes的包管理工具。使用Helm可以快速的安装和部署应用到Kubernetes上。

1.部署Helm
```
cd /usr/local/src
# 官方包
wget https://get.helm.sh/helm-v3.15.2-linux-amd64.tar.gz
# 国内访问
wget https://opsany.oss-cn-beijing.aliyuncs.com/helm-v3.15.2-linux-amd64.tar.gz
tar zxf helm-v3.15.2-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/
```

2.验证安装是否成功
```
[root@linux-node1 ~]# helm version
version.BuildInfo{Version:"v3.15.2", GitCommit:"1a500d5625419a524fdae4b33de351cc4f58ec35", GitTreeState:"clean", GoVersion:"go1.22.4"}
```

> ------------------------------------------------------------------------------

## 如何新增Kubernetes Node节点

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
