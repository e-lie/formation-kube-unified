# TP Fichiers locaux + random 

**Objectif : Une autre recette Terraform sans cloud mais plus complexe**

### 1. Lire la recette et chercher à comprendre son fonctionnement. 

- lire la documentation du nouveau provider `random` 
- où est déclarée la variable `words` ? et où est déclaré son contenu ? 
- à quoi sert `num_files` et `count` ?

### 2. Lancer la recette 

- Que se passe-t-il ? 
- Combien de ressources sont générées ? Pourquoi ?
- Quelles propriété du provider `random` est évidente quand on demande un nouveau `plan` ?

### 3. Modifier et relancer la recette 

- Modifier la variable `num_files`
- Modifier la variable `words` 
- Modifier la fonction de transformation de `words` 
- Ajouter le provider `hashicord_archive` et une `data` (attention!) pour faire un fichier zip avec le dossier généré par la recette

### 4. Terminer en lançant la destruction

- terraform destroy



