
export BASE_KUBE_DOMAIN="${TF_VAR_subdomain}.dopl.uk"

# ssh-add ~/.ssh/id_stagiaire

export KUBECONFIG="${HOME}/.kube/kube-${BASE_KUBE_DOMAIN}.yaml"

scp root@$BASE_KUBE_DOMAIN:/etc/kubernetes/admin.conf $KUBECONFIG

export BASE_KUBE_IP=$(dig +short $BASE_KUBE_DOMAIN)

sed -i "s/10.0.1.1/$BASE_KUBE_IP/g" $KUBECONFIG
