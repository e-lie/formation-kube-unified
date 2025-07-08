
## API kubeadm pour manipuler la plupart des composants

Configurer le cluster avec l'API kubeadm:

- documentation officielle https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/control-plane-flags/
- article zwindler: https://blog.zwindler.fr/2023/12/17/kubeadmcfg-introduction-api-kubeadm/
- article stephane robert: https://blog.stephane-robert.info/docs/conteneurs/orchestrateurs/kubernetes/kubeadm/

Configurer les DNS du cluster: 

- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/

Reconfigurer les composants de kubernetes:

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-reconfigure/

Upgrader les noeuds workers:

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/

## ETCD

tester la santé d'un noeud etcd: `curl -k http://10.0.1.1:2379/health` ou `etcdctl --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379 endpoint health`

lister les membre du cluster : `etcdctl --endpoints=http://10.0.1.1:2379 member list`

Administrer et reconfigurer etcd : https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/

## Configuration des elements du cluster


```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
controllerManager:
  extraArgs:
    # Limite le nombre maximal de Pods par nœud
    max-pods: "110"

    # Période d'attente avant de marquer un nœud comme non prêt
    node-monitor-grace-period: "40s"

    # Délai avant l'éviction des Pods lorsque le nœud est défectueux
    pod-eviction-timeout: "5m"

    # Activation du garbage collector pour nettoyer les objets orphelins
    enable-garbage-collector: "true"
    concurrent-gc-syncs: "30"

    # Contrôle de la synchronisation des déploiements
    deployment-controller-sync-period: "30s"
    
    # Activer PodTopologySpread
    feature-gates: "PodTopologySpread=true"

  extraVolumes:
    # Volumes supplémentaires pour configurer le cloud provider
    - name: cloud-config
      hostPath: /etc/kubernetes/cloud-config
      mountPath: /etc/kubernetes/cloud-config
      readOnly: true
```


## Apiserver

Chiffrer les donnéez de kubernetes "at rest"

- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

