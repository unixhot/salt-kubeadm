1.安装并配置NFS
```
[root@linux-node1 ~]# yum install -y nfs-utils rpcbind
[root@linux-node1 ~]# mkdir -p /data/k8s-nfs
[root@linux-node1 ~]# vim /etc/exports
/data/k8s-nfs *(rw,sync,no_root_squash)
```

启动NFS
```
[root@linux-node1 ~]# systemctl enable rpcbind nfs
[root@linux-node1 ~]# systemctl start rpcbind nfs
```

2.创建PV
```
[root@linux-node1 ~]# vim nfs-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
spec:
  capacity:
storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs
  nfs:
    path: /data/k8s-nfs/pv-demo
    server: 192.168.56.11

[root@linux-node1 ~]# kubectl create -f nfs-pv.yaml 
persistentvolume "pv-demo" created

[root@linux-node1 ~]# kubectl get pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
pv-demo   1Gi        RWO            Recycle          Available             nfs                      15s
```
