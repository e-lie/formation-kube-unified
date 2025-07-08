#!/usr/bin/env python3
"""
Script pour lister les instances EC2 par région et exporter en TOML
Utilise AWS CLI au lieu de boto3
"""

import subprocess
import json
import sys
import argparse
from datetime import datetime
import toml

def run_aws_command(command):
    """Exécute une commande AWS CLI et retourne le résultat"""
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            capture_output=True, 
            text=True, 
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Erreur AWS CLI: {e}")
        print(f"   Commande: {command}")
        print(f"   Erreur: {e.stderr}")
        return None

def get_regions(profile=None):
    """Récupère la liste des régions AWS"""
    profile_arg = f"--profile {profile}" if profile else ""
    cmd = f"aws ec2 describe-regions --query 'Regions[].RegionName' --output json {profile_arg}"
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_instances_in_region(region, profile=None):
    """Récupère les instances EC2 d'une région spécifique"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    # Commande simple comme celle qui marche
    cmd = f"aws ec2 describe-instances --region {region} --query 'Reservations[*].Instances[*].InstanceId' --output json {profile_arg}"
    
    result = run_aws_command(cmd)
    if result:
        try:
            instance_ids_raw = json.loads(result)
            
            # Aplatir la liste (cas où on a des listes imbriquées)
            instance_ids = []
            for item in instance_ids_raw:
                if isinstance(item, list):
                    instance_ids.extend(item)
                else:
                    instance_ids.append(item)
            
            print(f"    Debug: {len(instance_ids)} IDs trouvés dans {region}")
            
            # Si on a des IDs, récupérer les détails
            if instance_ids:
                # Simplification : récupérer juste état et type, pas les tags compliqués
                query = "Reservations[*].Instances[*].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType}"
                details_cmd = f'aws ec2 describe-instances --region {region} --instance-ids {" ".join(instance_ids)} --query "{query}" --output json {profile_arg}'
                
                details_result = run_aws_command(details_cmd)
                if details_result:
                    detailed_instances_raw = json.loads(details_result)
                    
                    # Aplatir la structure imbriquée
                    detailed_instances = []
                    for item in detailed_instances_raw:
                        if isinstance(item, list):
                            detailed_instances.extend(item)
                        else:
                            detailed_instances.append(item)
                    
                    print(f"    Debug: Détails récupérés pour {len(detailed_instances)} instances")
                    
                    # Ajouter un champ Name vide pour chaque instance (on peut l'améliorer plus tard)
                    for inst in detailed_instances:
                        if isinstance(inst, dict):
                            inst['Name'] = ""
                    
                    return detailed_instances
                else:
                    # Si on ne peut pas récupérer les détails, retourner juste les IDs
                    return [{"InstanceId": iid, "State": "unknown", "InstanceType": "unknown", "Name": ""} for iid in instance_ids]
            return []
        except json.JSONDecodeError as e:
            print(f"    Erreur JSON dans {region}: {e}")
            print(f"    Résultat brut: {result}")
            return []
    return []

def format_instance_for_toml(instance):
    """Formate une instance pour l'export TOML"""
    # Nettoyer les valeurs None
    formatted = {}
    for key, value in instance.items():
        if value is not None:
            # Convertir les dates ISO en string lisible
            if key == 'LaunchTime' and isinstance(value, str):
                try:
                    dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                    formatted[key] = dt.strftime('%Y-%m-%d %H:%M:%S UTC')
                except:
                    formatted[key] = value
            else:
                formatted[key] = value
        else:
            formatted[key] = ""
    
    return formatted

def list_ec2_instances(profile=None, regions=None, output_file=None):
    """Liste toutes les instances EC2 et génère un fichier TOML"""
    
    print("🔍 Récupération des instances EC2...")
    
    # Obtenir les régions à scanner
    if regions:
        target_regions = regions
    else:
        print("📍 Récupération de la liste des régions...")
        target_regions = get_regions(profile)
        if not target_regions:
            print("❌ Impossible de récupérer les régions")
            return False
    
    # Structure pour le TOML
    toml_data = {
        'metadata': {
            'scan_date': datetime.now().isoformat(),
            'profile': profile if profile else 'default',
            'total_regions_scanned': len(target_regions),
            'regions_scanned': target_regions
        },
        'summary': {
            'total_instances': 0,
            'by_state': {},
            'by_region': {}
        },
        'regions': {}
    }
    
    # Scanner chaque région
    for region in target_regions:
        print(f"  📍 Scan région: {region}")
        
        instances = get_instances_in_region(region, profile)
        
        if instances:
            # Version simplifiée : juste les IDs et infos essentielles
            instance_list = []
            instance_details = {}
            
            for instance in instances:
                instance_id = instance['InstanceId']
                instance_list.append(instance_id)
                
                # Détails minimaux pour chaque instance
                instance_details[instance_id] = {
                    'id': instance_id,
                    'state': instance.get('State', 'unknown'),
                    'type': instance.get('InstanceType', 'unknown'),
                    'name': instance.get('Name', '') or ''
                }
                
                # Mettre à jour les statistiques
                toml_data['summary']['total_instances'] += 1
                
                state = instance.get('State', 'unknown')
                if state not in toml_data['summary']['by_state']:
                    toml_data['summary']['by_state'][state] = 0
                toml_data['summary']['by_state'][state] += 1
            
            # Structure TOML simplifiée
            toml_data['regions'][region] = {
                'instance_count': len(instances),
                'instance_ids': instance_list,  # Liste simple des IDs
                'instances': instance_details   # Détails par ID
            }
            toml_data['summary']['by_region'][region] = len(instances)
            
            print(f"    ✅ {len(instances)} instances trouvées")
        else:
            print(f"    ⭕ Aucune instance")
            toml_data['regions'][region] = {
                'instance_count': 0,
                'instances': {}
            }
            toml_data['summary']['by_region'][region] = 0
    
    # Générer le fichier TOML
    if not output_file:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = f"ec2_instances_{timestamp}.toml"
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            toml.dump(toml_data, f)
        
        print(f"\n✅ Fichier TOML généré: {output_file}")
        print(f"📊 Résumé: {toml_data['summary']['total_instances']} instances dans {len(target_regions)} régions")
        
        # Afficher le résumé par état
        if toml_data['summary']['by_state']:
            print("\n📈 Répartition par état:")
            for state, count in toml_data['summary']['by_state'].items():
                print(f"  • {state}: {count}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de l'écriture du fichier TOML: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='Liste les instances EC2 par région et exporte en TOML'
    )
    parser.add_argument(
        '--profile',
        help='Profil AWS à utiliser',
        default=None
    )
    parser.add_argument(
        '--regions',
        nargs='+',
        help='Régions spécifiques à scanner (par défaut: toutes)',
        default=None
    )
    parser.add_argument(
        '--output',
        help='Fichier de sortie TOML',
        default=None
    )
    parser.add_argument(
        '--check-cli',
        action='store_true',
        help='Vérifier la configuration AWS CLI'
    )
    
    args = parser.parse_args()
    
    # Vérifier la CLI AWS
    if args.check_cli:
        print("🔧 Vérification de la configuration AWS CLI...")
        profile_arg = f"--profile {args.profile}" if args.profile else ""
        identity_cmd = f"aws sts get-caller-identity {profile_arg}"
        result = run_aws_command(identity_cmd)
        
        if result:
            identity = json.loads(result)
            print(f"✅ Connecté au compte: {identity.get('Account')}")
            print(f"   Utilisateur/Rôle: {identity.get('Arn')}")
        else:
            print("❌ Impossible de vérifier l'identité AWS")
            sys.exit(1)
    
    # Vérifier que toml est installé
    try:
        import toml
    except ImportError:
        print("❌ Le module 'toml' n'est pas installé")
        print("   Installation: pip install toml")
        sys.exit(1)
    
    # Lancer le scan
    success = list_ec2_instances(args.profile, args.regions, args.output)
    
    if not success:
        sys.exit(1)
    
    print("\n🎉 Scan terminé avec succès!")

if __name__ == '__main__':
    main()