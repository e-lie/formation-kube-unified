---
title: "Outils de la formation"
description: "Guide Outils de la formation"
sidebar:
  order: 101
---




## Le dépôt git "fil rouge"

**Un dépôt va vous fournir les corrections de TP durant la formation :**

https://github.com/e-lie/formation-kube-unified :


## Ouvrir le bureau VNC

### VSCode


## Plateforme Guacamole

- Accédez à Guacamole à l'adresse fournie par le formateur, par exemple `guacamole.k8s.dopl.uk` ou `guacamole.uptime-formation.fr`.

- Accédez à votre VM via l'interface Guacamole avec le login fourni par le formateur (traditionnellement votre prenom en minuscule et sans accent et un mot de passe générique indiqué à l'oral)

- Pour accéder au copier-coller de Guacamole, il faut appuyer simultanément sur **`Ctrl+Alt+Shift`** et utiliser la zone de texte qui s'affiche (réappuyer sur `Ctrl+Alt+Shift` pour revenir à la VM).

- Cependant comme ce copier-coller est capricieux, il est conseillé d'ouvrir cette page de doc dans le navigateur à l'intérieur de guacamole et de suivre à partir de la machine distance.

## Quelques soucis épisodiques et solutions

### avec le snap firefox

```sh
$ sudo add-apt-repository ppa:mozillateam/ppa


$ echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox
Pin: version 1:1snap1-0ubuntu2
Pin-Priority: -1
' | sudo tee /etc/apt/preferences.d/mozilla-firefox


$ sudo snap remove firefox


$ sudo apt install firefox

```


