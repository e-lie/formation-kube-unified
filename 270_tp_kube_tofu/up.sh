

ssh-add ~/.ssh/id_stagiaire

source env_tools/params.env
source env_tools/secrets.env

terraform init
terraform apply

# bash env_tools/get_kubeconfig.sh

# source env_tools/kubeconfig.env
