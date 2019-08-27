# 使用NFS作为Kubernetes持久化存储PV/PVC

## 1.安装并配置NFS
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

## 2.创建PV
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

## 3.创建PVC
```
[root@linux-node1 ~]# vim nfs-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs


[root@linux-node1 ~]# kubectl create -f nfs-pvc.yaml 
persistentvolumeclaim "pvc-demo" created
[root@linux-node1 ~]# kubectl get pvc
NAME       STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-demo   Bound     pv-demo   1Gi        RWO            nfs            6s
```

## 4.使用PVC
```
[root@linux-node1 ~]# vim nginx-deployment-pvc.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.13.12
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: pvc-demo
      volumes:
      - name: pvc-demo
        persistentVolumeClaim:
          claimName: pvc-demo
```
