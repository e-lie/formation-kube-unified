#!/usr/bin/env python3
"""
Script pour terminer les instances EC2 listées dans un fichier TOML
Utilise AWS CLI au lieu de boto3
"""

import subprocess
import json
import sys
import argparse
from datetime import datetime
import toml
import os

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

def load_toml_file(filename):
    """Charge et parse le fichier TOML"""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            return toml.load(f)
    except FileNotFoundError:
        print(f"❌ Fichier TOML non trouvé: {filename}")
        return None
    except toml.TomlDecodeError as e:
        print(f"❌ Erreur de format TOML: {e}")
        return None
    except Exception as e:
        print(f"❌ Erreur lors de la lecture du fichier: {e}")
        return None

def extract_instances_from_toml(toml_data, states_filter=None):
    """Extrait les instances du fichier TOML avec filtrage optionnel"""
    instances_by_region = {}
    total_instances = 0
    
    if 'regions' not in toml_data:
        print("❌ Format TOML invalide: section 'regions' manquante")
        return None, 0
    
    # Filtres par défaut (éviter les instances déjà terminées)
    if states_filter is None:
        states_filter = ['running', 'stopped', 'stopping', 'pending']
    
    for region, region_data in toml_data['regions'].items():
        # Support nouveau format (instance_ids + instances) et ancien format
        instances_to_terminate = []
        
        # Nouveau format avec instance_ids
        if 'instance_ids' in region_data and 'instances' in region_data:
            for instance_id in region_data['instance_ids']:
                if instance_id in region_data['instances']:
                    instance_data = region_data['instances'][instance_id]
                    instance_state = instance_data.get('state', 'unknown')
                    
                    # Vérifier si l'instance doit être terminée selon les filtres
                    if instance_state in states_filter:
                        instances_to_terminate.append({
                            'id': instance_id,
                            'name': instance_data.get('name', 'Sans nom'),
                            'type': instance_data.get('type', 'Inconnu'),
                            'state': instance_state
                        })
                        total_instances += 1
        
        # Ancien format pour compatibilité
        elif 'instances' in region_data:
            for instance_key, instance_data in region_data['instances'].items():
                instance_id = instance_data.get('InstanceId') or instance_data.get('id')
                instance_state = instance_data.get('State') or instance_data.get('state')
                
                if not instance_id:
                    continue
                
                # Vérifier si l'instance doit être terminée selon les filtres
                if instance_state in states_filter:
                    instances_to_terminate.append({
                        'id': instance_id,
                        'name': instance_data.get('Name', instance_data.get('name', 'Sans nom')),
                        'type': instance_data.get('InstanceType', instance_data.get('type', 'Inconnu')),
                        'state': instance_state
                    })
                    total_instances += 1
        
        if instances_to_terminate:
            instances_by_region[region] = instances_to_terminate
    
    return instances_by_region, total_instances

def verify_instances_exist(instances_by_region, profile=None):
    """Vérifie que les instances existent encore avant de les terminer"""
    profile_arg = f"--profile {profile}" if profile else ""
    verified_instances = {}
    
    for region, instances in instances_by_region.items():
        instance_ids = [inst['id'] for inst in instances]
        
        if not instance_ids:
            continue
        
        print(f"🔍 Vérification des instances dans {region}...")
        
        # Vérifier l'existence et l'état actuel
        cmd = f'''aws ec2 describe-instances --region {region} --instance-ids {' '.join(instance_ids)} --query "Reservations[*].Instances[*].{{InstanceId:InstanceId,State:State.Name}}" --output json {profile_arg}'''
        
        result = run_aws_command(cmd)
        if result:
            try:
                current_instances_raw = json.loads(result)
                
                # Aplatir la structure imbriquée comme dans l'autre script
                current_instances = []
                for item in current_instances_raw:
                    if isinstance(item, list):
                        current_instances.extend(item)
                    else:
                        current_instances.append(item)
                
                verified_list = []
                
                for inst in instances:
                    # Trouver l'état actuel
                    current_state = None
                    for current_inst in current_instances:
                        if isinstance(current_inst, dict) and current_inst.get('InstanceId') == inst['id']:
                            current_state = current_inst.get('State')
                            break
                    
                    if current_state:
                        inst['current_state'] = current_state
                        if current_state not in ['terminated', 'terminating']:
                            verified_list.append(inst)
                        else:
                            print(f"  ⚠️  {inst['id']} déjà {current_state}")
                    else:
                        print(f"  ❌ {inst['id']} non trouvée")
                
                if verified_list:
                    verified_instances[region] = verified_list
                    print(f"  ✅ {len(verified_list)} instances à terminer")
                else:
                    print(f"  ⭕ Aucune instance à terminer")
            
            except json.JSONDecodeError:
                print(f"  ❌ Erreur lors de la vérification des instances")
        else:
            print(f"  ❌ Impossible de vérifier les instances dans {region}")
    
    return verified_instances

def terminate_instances(instances_by_region, profile=None, dry_run=False):
    """Termine les instances EC2"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {
        'success': [],
        'failed': [],
        'total': 0
    }
    
    for region, instances in instances_by_region.items():
        instance_ids = [inst['id'] for inst in instances]
        results['total'] += len(instance_ids)
        
        if not instance_ids:
            continue
        
        print(f"\n🗑️  Terminaison des instances dans {region}...")
        
        # Afficher les détails des instances à terminer
        for inst in instances:
            state_info = f" (actuellement: {inst.get('current_state', inst['state'])})" if inst.get('current_state') else ""
            print(f"  • {inst['id']} - {inst['name']} ({inst['type']}){state_info}")
        
        if dry_run:
            print(f"  🔍 DRY-RUN: {len(instance_ids)} instances seraient terminées")
            results['success'].extend(instance_ids)
            continue
        
        # Terminer les instances
        cmd = f"aws ec2 terminate-instances --region {region} --instance-ids {' '.join(instance_ids)} --output json {profile_arg}"
        
        result = run_aws_command(cmd)
        if result:
            try:
                termination_result = json.loads(result)
                terminated_instances = termination_result.get('TerminatingInstances', [])
                
                for term_inst in terminated_instances:
                    instance_id = term_inst['InstanceId']
                    current_state = term_inst['CurrentState']['Name']
                    previous_state = term_inst['PreviousState']['Name']
                    
                    print(f"  ✅ {instance_id}: {previous_state} → {current_state}")
                    results['success'].append(instance_id)
                
            except json.JSONDecodeError:
                print(f"  ❌ Erreur lors du parsing de la réponse")
                results['failed'].extend(instance_ids)
        else:
            print(f"  ❌ Échec de la terminaison dans {region}")
            results['failed'].extend(instance_ids)
    
    return results

def show_summary(toml_data):
    """Affiche un résumé du fichier TOML"""
    metadata = toml_data.get('metadata', {})
    summary = toml_data.get('summary', {})
    
    print("📋 Résumé du fichier TOML:")
    print(f"  • Date de scan: {metadata.get('scan_date', 'Inconnue')}")
    print(f"  • Profil AWS: {metadata.get('profile', 'default')}")
    print(f"  • Régions scannées: {metadata.get('total_regions_scanned', 0)}")
    print(f"  • Total instances: {summary.get('total_instances', 0)}")
    
    if summary.get('by_state'):
        print("  • Répartition par état:")
        for state, count in summary['by_state'].items():
            print(f"    - {state}: {count}")

def main():
    parser = argparse.ArgumentParser(
        description='Termine les instances EC2 listées dans un fichier TOML'
    )
    parser.add_argument(
        'toml_file',
        help='Fichier TOML contenant les instances à terminer'
    )
    parser.add_argument(
        '--profile',
        help='Profil AWS à utiliser',
        default=None
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Afficher ce qui serait terminé sans le faire'
    )
    parser.add_argument(
        '--states',
        nargs='+',
        help='États des instances à terminer (défaut: running stopped pending)',
        default=['running', 'stopped', 'pending', 'stopping']
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Terminer sans confirmation'
    )
    parser.add_argument(
        '--summary-only',
        action='store_true',
        help='Afficher seulement le résumé du fichier TOML'
    )
    
    args = parser.parse_args()
    
    # Vérifier que toml est installé
    try:
        import toml
    except ImportError:
        print("❌ Le module 'toml' n'est pas installé")
        print("   Installation: pip install toml")
        sys.exit(1)
    
    # Charger le fichier TOML
    print(f"📂 Chargement du fichier: {args.toml_file}")
    toml_data = load_toml_file(args.toml_file)
    
    if not toml_data:
        sys.exit(1)
    
    # Afficher le résumé
    show_summary(toml_data)
    
    if args.summary_only:
        sys.exit(0)
    
    # Extraire les instances à terminer
    print(f"\n🎯 Recherche des instances dans les états: {', '.join(args.states)}")
    instances_by_region, total_count = extract_instances_from_toml(toml_data, args.states)
    
    if not instances_by_region or total_count == 0:
        print("✅ Aucune instance à terminer trouvée")
        sys.exit(0)
    
    print(f"🔍 {total_count} instances candidates à la terminaison")
    
    # Vérifier l'existence des instances
    verified_instances = verify_instances_exist(instances_by_region, args.profile)
    
    if not verified_instances:
        print("✅ Aucune instance valide à terminer")
        sys.exit(0)
    
    verified_count = sum(len(instances) for instances in verified_instances.values())
    print(f"\n⚠️  {verified_count} instances seront terminées")
    
    # Demander confirmation si pas de force ou dry-run
    if not args.force and not args.dry_run:
        print("\n" + "="*60)
        print("⚠️  ATTENTION: Cette action va TERMINER les instances EC2!")
        print("   Cette action est IRRÉVERSIBLE!")
        print("="*60)
        
        confirm = input("\nTaper 'TERMINATE' pour confirmer: ")
        if confirm != 'TERMINATE':
            print("❌ Opération annulée")
            sys.exit(0)
    
    # Terminer les instances
    results = terminate_instances(verified_instances, args.profile, args.dry_run)
    
    # Afficher les résultats
    print(f"\n📊 Résultats:")
    print(f"  • Total traité: {results['total']}")
    print(f"  • Succès: {len(results['success'])}")
    print(f"  • Échecs: {len(results['failed'])}")
    
    if results['failed']:
        print(f"\n❌ Instances en échec:")
        for instance_id in results['failed']:
            print(f"  • {instance_id}")
    
    if args.dry_run:
        print(f"\n🔍 Mode DRY-RUN: Aucune instance n'a été réellement terminée")
    else:
        print(f"\n✅ Terminaison {'simulée' if args.dry_run else 'lancée'} avec succès!")

if __name__ == '__main__':
    main()