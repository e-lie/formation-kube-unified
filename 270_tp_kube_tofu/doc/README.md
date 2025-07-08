
# Kubetofu : Cluster on premise multi-noeuds avec `terraform` et `kubeadm`

Ce projet de code utilise Terraform pour provisionner des machines Ubuntu server dans le cloud (ici Hetznercloud).

Ces machines sont ensuite configurées avec un réseau privé wireguard et un firewall (UFW).

Puis etcd et déployé en tant que service systemd sur 3 des noeuds.

Puis kubeadm est utilisé pour initialiser le premier noeud en tant que control plane et joindre les autres noeuds en tant que workers.

## Déploiement

- récupérez un token hetznercloud pour le provisionning des VPS et un token digitalocean pour la gestion des domaines à renseigner dans `scripts/secrets.env`

- modifiez les paramètres dans `env_tools/params.env` pour renseigner votre nom en tant que `subdomain` et 


Ce projet et basé sur [https://github.com/hobby-kube/guide]
et sur [https://github.com/hobby-kube/provisioning]

[Original README from hobby-kube provisionning](./README.original.md)