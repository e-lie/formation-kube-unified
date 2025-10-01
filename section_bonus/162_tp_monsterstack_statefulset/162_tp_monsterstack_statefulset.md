---
title: TP - MonsterStack avec Redis StatefulSet
---

# TP : Déployer MonsterStack avec Redis en mode répliqué (StatefulSet)

## Objectifs

Dans ce TP, nous allons améliorer notre déploiement MonsterStack en remplaçant le Redis simple par un cluster Redis répliqué utilisant un StatefulSet. 

Ce qui illustrera un cas classique de déploiement stateful simple.

## Architecture cible

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Frontend x3   │────▶│  ImageBackend   │────▶│  Redis Cluster  │
│   (Deployment)  │     │   (Deployment)  │     │  (StatefulSet)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                           │
                                                  ┌────────┼────────┐
                                                  │        │        │
                                              redis-0  redis-1  redis-2
                                              (master)  (slave)  (slave)
```

## Comprendre les StatefulSets

Un StatefulSet est un contrôleur Kubernetes qui gère le déploiement et la mise à l'échelle d'un ensemble de Pods, avec les garanties suivantes :

- **Identité stable** : Chaque pod a un nom persistant (redis-0, redis-1, redis-2)
- **Ordre de déploiement** : Les pods sont créés et supprimés dans l'ordre
- **Stockage persistant** : Chaque pod peut avoir son propre volume persistant
- **Réseau stable** : Nom DNS stable pour chaque pod

### Pourquoi utiliser un StatefulSet pour Redis ?

Redis en mode réplication nécessite :
- Une identification stable du master (redis-0)
- Une persistance des données même après redémarrage
- Une configuration différente pour master et slaves

## Étape 2 : Créer la ConfigMap Redis

Créez un fichier `redis-configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: default
data:
  master.conf: |
    # Configuration du Master Redis
    bind 0.0.0.0
    protected-mode no
    port 6379
    tcp-keepalive 300
    
    daemonize no
    loglevel notice
    databases 16
    
    # Persistance
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    
    # Mémoire
    maxmemory 256mb
    maxmemory-policy allkeys-lru

  slave.conf: |
    # Configuration des Replicas Redis
    bind 0.0.0.0
    protected-mode no
    port 6379
    tcp-keepalive 300
    
    daemonize no
    loglevel notice
    databases 16
    
    # Réplication - le master est toujours redis-0
    replicaof redis-0.redis-headless 6379
    slave-read-only yes
    
    dir /data
    
    # Mémoire
    maxmemory 256mb
    maxmemory-policy allkeys-lru
```

**En résumé :**
- Deux configurations : une pour le master, une pour les slaves
- Le master (redis-0) a la configuration de persistance activée
- Les slaves pointent vers `redis-0.redis-headless` pour la réplication

## Étape 3 : Créer les Services

### Service Headless pour la découverte

Créez un fichier `redis-services.yaml` :

```yaml
# Service Headless pour la découverte des pods
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  namespace: default
  labels:
    app: redis
spec:
  type: ClusterIP
  clusterIP: None  # Headless service
  ports:
    - port: 6379
      targetPort: 6379
      name: redis
  selector:
    app: redis
---
# Service pour accéder au master uniquement
apiVersion: v1
kind: Service
metadata:
  name: redis-master
  namespace: default
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: 6379
      name: redis
  selector:
    app: redis
    statefulset.kubernetes.io/pod-name: redis-0
---
# Service pour accéder à tous les pods (lecture répartie)
apiVersion: v1
kind: Service
metadata:
  name: redis-replicas
  namespace: default
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: 6379
      name: redis
  selector:
    app: redis
```

**Points clés :**
- `redis-headless` : Service headless pour DNS stable (redis-0.redis-headless, redis-1.redis-headless, etc.)
- `redis-master` : Pointe uniquement vers redis-0 pour les écritures
- `redis-replicas` : Load balance sur tous les pods pour les lectures

## Étape 4 : Créer le StatefulSet

Créez un fichier `redis-statefulset.yaml` :

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: default
spec:
  serviceName: redis-headless  # Service headless associé
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      initContainers:
        - name: config
          image: redis:7.2-alpine
          command:
            - sh
            - -c
            - |
              set -ex
              # Déterminer si c'est le master ou un slave
              if [ "$(hostname)" = "redis-0" ]; then
                echo "Initializing as MASTER"
                cp /mnt/config-map/master.conf /etc/redis/redis.conf
              else
                echo "Initializing as REPLICA"
                cp /mnt/config-map/slave.conf /etc/redis/redis.conf
              fi
          volumeMounts:
            - name: redis-config
              mountPath: /mnt/config-map
            - name: config
              mountPath: /etc/redis/
      containers:
        - name: redis
          image: redis:7.2-alpine
          command:
            - redis-server
            - /etc/redis/redis.conf
          ports:
            - containerPort: 6379
              name: redis
          volumeMounts:
            - name: data
              mountPath: /data
            - name: config
              mountPath: /etc/redis
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            tcpSocket:
              port: redis
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - redis-cli ping | grep PONG
            initialDelaySeconds: 15
            periodSeconds: 5
      volumes:
        - name: redis-config
          configMap:
            name: redis-config
        - name: config
          emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

**Points clés :**
- `initContainer` : Configure le pod selon son ordinal (redis-0 = master, autres = slaves)
- `volumeClaimTemplates` : Crée un PVC unique pour chaque pod
- Les probes vérifient la santé de Redis

## Étape 5 : Mettre à jour l'application

Modifiez le service Redis dans les déploiements Frontend et ImageBackend pour utiliser `redis-master` pour les écritures :

```yaml
# Dans frontend.yaml et imagebackend.yaml
env:
  - name: REDIS_HOST
    value: "redis-master"  # Utiliser le service master pour les écritures
  - name: REDIS_PORT
    value: "6379"
```

## Étape 6 : Déployer l'application

```bash
# Créer le namespace si nécessaire
kubectl create namespace default

# Déployer Redis StatefulSet
kubectl apply -f redis-configmap.yaml
kubectl apply -f redis-services.yaml
kubectl apply -f redis-statefulset.yaml

# Attendre que les pods Redis soient prêts
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s

# Déployer le reste de l'application
kubectl apply -f frontend.yaml
kubectl apply -f imagebackend.yaml
kubectl apply -f monsterstack-ingress.yaml
```

## Étape 7 : Vérifier le déploiement

### Vérifier les pods

```bash
# Voir l'ordre de création des pods
kubectl get pods -l app=redis -w

# Vérifier les noms stables
kubectl get pods -l app=redis
# Doit afficher : redis-0, redis-1, redis-2
```

### Vérifier la réplication

```bash
# Se connecter au master
kubectl exec -it redis-0 -- redis-cli

# Dans redis-cli, vérifier le statut
127.0.0.1:6379> INFO replication
# Doit montrer role:master et 2 connected_slaves

# Tester l'écriture sur le master
127.0.0.1:6379> SET test "Hello from master"
127.0.0.1:6379> exit

# Vérifier la réplication sur un slave
kubectl exec -it redis-1 -- redis-cli GET test
# Doit retourner "Hello from master"
```

### Vérifier les services

```bash
# Vérifier les endpoints
kubectl get endpoints redis-headless
kubectl get endpoints redis-master
kubectl get endpoints redis-replicas

# Tester la résolution DNS
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup redis-0.redis-headless
```

## Étape 8 : Tester la persistance

```bash
# Créer des données
kubectl exec -it redis-0 -- redis-cli SET persistent "data"

# Supprimer le pod master
kubectl delete pod redis-0

# Attendre la recréation
kubectl wait --for=condition=ready pod/redis-0 --timeout=120s

# Vérifier que les données sont toujours là
kubectl exec -it redis-0 -- redis-cli GET persistent
# Doit retourner "data"
```

## Étape 9 : Scaler le StatefulSet

```bash
# Augmenter le nombre de replicas
kubectl scale statefulset redis --replicas=5

# Observer l'ordre de création
kubectl get pods -l app=redis -w

# Réduire
kubectl scale statefulset redis --replicas=3

# Observer l'ordre de suppression (inverse)
kubectl get pods -l app=redis -w
```

## Points d'attention

### Avantages du StatefulSet pour Redis

1. **Identité stable** : redis-0 est toujours le master
2. **Persistance** : Chaque pod a son propre volume
3. **Ordre** : Démarrage et arrêt ordonnés
4. **DNS stable** : Chaque pod a un nom DNS prévisible

### Limitations et considérations

1. **Failover manuel** : Si redis-0 tombe, pas de promotion automatique
2. **Split-brain** : Risque si le réseau se partitionne
3. **Performance** : Les slaves sont en lecture seule

### Pour aller plus loin

1. **Redis Sentinel** : Pour le failover automatique
2. **Redis Cluster** : Pour le sharding horizontal
3. **Operators** : Redis Operator pour gestion avancée
4. **Monitoring** : Prometheus + Redis Exporter

## Exercices supplémentaires

1. **Backup/Restore** : Implémenter une stratégie de sauvegarde
2. **Monitoring** : Ajouter des métriques Prometheus
3. **Sécurité** : Activer l'authentification Redis
4. **Performance** : Configurer la persistence AOF vs RDB

## Nettoyage

```bash
# Supprimer toutes les ressources
kubectl delete -f .

# Supprimer les PVC
kubectl delete pvc -l app=redis
```

## Conclusion

Dans ce TP, vous avez appris à :
- Utiliser les StatefulSets pour des applications stateful
- Configurer Redis en mode réplication master/slave
- Gérer le stockage persistant avec les volumeClaimTemplates
- Utiliser les services headless pour la découverte

Les StatefulSets sont essentiels pour les applications qui nécessitent une identité stable, du stockage persistant et un ordre de déploiement, comme les bases de données et les systèmes de cache distribués.