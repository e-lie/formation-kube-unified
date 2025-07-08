#!/bin/bash

# Mettre à jour le système
apt-get update

# Créer l'utilisateur et configurer SSH
if ! id "terraform" &>/dev/null; then
  useradd -m -s /bin/bash terraform
  usermod -aG sudo terraform
  echo 'terraform ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
fi

# Créer le répertoire .ssh
mkdir -p /home/terraform/.ssh
chmod 700 /home/terraform/.ssh

# Ajouter la clé publique SSH
echo "${ssh_public_key}" > /home/terraform/.ssh/authorized_keys
chmod 600 /home/terraform/.ssh/authorized_keys
chown -R terraform:terraform /home/terraform/.ssh

# Installer et configurer nginx
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx

# Créer la page d'accueil avec numéro de serveur
echo '<h1>Server ${server_number} - Feature: ${feature_name} (${workspace})</h1>' > /var/www/html/index.html
echo '<p>Instance ID: ${instance_id}</p>' >> /var/www/html/index.html
echo '<p>Load balancer avec user-data</p>' >> /var/www/html/index.html

echo "Configuration serveur ${server_number} terminée avec user-data"