#!/usr/bin/env python3
"""
Script pour supprimer les ressources AWS listées dans un fichier TOML
Support: EC2, VPC, Subnets, Security Groups, Load Balancers, etc.
"""

import subprocess
import json
import sys
import argparse
from datetime import datetime
import toml
import os
import time

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
        if e.stderr:
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

# =====================================================================
# FONCTIONS DE SUPPRESSION POUR CHAQUE TYPE DE RESSOURCE
# =====================================================================

def delete_ec2_instances(region, resource_ids, profile=None, dry_run=False):
    """Supprime les instances EC2"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} instances EC2 seraient terminées")
        return {"success": resource_ids, "failed": []}
    
    cmd = f"aws ec2 terminate-instances --region {region} --instance-ids {' '.join(resource_ids)} --output json {profile_arg}"
    result = run_aws_command(cmd)
    
    if result:
        try:
            termination_result = json.loads(result)
            success = [inst['InstanceId'] for inst in termination_result.get('TerminatingInstances', [])]
            failed = [rid for rid in resource_ids if rid not in success]
            return {"success": success, "failed": failed}
        except:
            return {"success": [], "failed": resource_ids}
    
    return {"success": [], "failed": resource_ids}

def delete_security_groups(region, resource_ids, profile=None, dry_run=False):
    """Supprime les security groups"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} security groups seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for sg_id in resource_ids:
        cmd = f"aws ec2 delete-security-group --region {region} --group-id {sg_id} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(sg_id)
        else:
            results["failed"].append(sg_id)
    
    return results

def delete_subnets(region, resource_ids, profile=None, dry_run=False):
    """Supprime les subnets"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} subnets seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for subnet_id in resource_ids:
        cmd = f"aws ec2 delete-subnet --region {region} --subnet-id {subnet_id} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(subnet_id)
        else:
            results["failed"].append(subnet_id)
    
    return results

def delete_internet_gateways(region, resource_ids, profile=None, dry_run=False):
    """Supprime les internet gateways"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} internet gateways seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for igw_id in resource_ids:
        # D'abord détacher de tous les VPCs
        describe_cmd = f"aws ec2 describe-internet-gateways --region {region} --internet-gateway-ids {igw_id} --query 'InternetGateways[0].Attachments[*].VpcId' --output text {profile_arg}"
        vpc_result = run_aws_command(describe_cmd)
        
        if vpc_result and vpc_result != "None":
            for vpc_id in vpc_result.split():
                detach_cmd = f"aws ec2 detach-internet-gateway --region {region} --internet-gateway-id {igw_id} --vpc-id {vpc_id} {profile_arg}"
                run_aws_command(detach_cmd)
        
        # Puis supprimer
        delete_cmd = f"aws ec2 delete-internet-gateway --region {region} --internet-gateway-id {igw_id} {profile_arg}"
        if run_aws_command(delete_cmd):
            results["success"].append(igw_id)
        else:
            results["failed"].append(igw_id)
    
    return results

def delete_nat_gateways(region, resource_ids, profile=None, dry_run=False):
    """Supprime les NAT gateways"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} NAT gateways seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for nat_id in resource_ids:
        cmd = f"aws ec2 delete-nat-gateway --region {region} --nat-gateway-id {nat_id} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(nat_id)
        else:
            results["failed"].append(nat_id)
    
    return results

def delete_route_tables(region, resource_ids, profile=None, dry_run=False):
    """Supprime les route tables"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} route tables seraient supprimées")
        return {"success": resource_ids, "failed": []}
    
    for rt_id in resource_ids:
        cmd = f"aws ec2 delete-route-table --region {region} --route-table-id {rt_id} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(rt_id)
        else:
            results["failed"].append(rt_id)
    
    return results

def delete_vpcs(region, resource_ids, profile=None, dry_run=False):
    """Supprime les VPCs"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} VPCs seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for vpc_id in resource_ids:
        cmd = f"aws ec2 delete-vpc --region {region} --vpc-id {vpc_id} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(vpc_id)
        else:
            results["failed"].append(vpc_id)
    
    return results

def delete_classic_load_balancers(region, resource_ids, profile=None, dry_run=False):
    """Supprime les Classic Load Balancers"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} Classic Load Balancers seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for elb_name in resource_ids:
        cmd = f"aws elb delete-load-balancer --region {region} --load-balancer-name {elb_name} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(elb_name)
        else:
            results["failed"].append(elb_name)
    
    return results

def delete_load_balancers_v2(region, resource_ids, profile=None, dry_run=False):
    """Supprime les Application/Network Load Balancers"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} ALB/NLB seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for lb_arn in resource_ids:
        cmd = f"aws elbv2 delete-load-balancer --region {region} --load-balancer-arn {lb_arn} {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(lb_arn)
        else:
            results["failed"].append(lb_arn)
    
    return results

def delete_rds_instances(region, resource_ids, profile=None, dry_run=False):
    """Supprime les instances RDS"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} instances RDS seraient supprimées")
        return {"success": resource_ids, "failed": []}
    
    for db_id in resource_ids:
        cmd = f"aws rds delete-db-instance --region {region} --db-instance-identifier {db_id} --skip-final-snapshot --delete-automated-backups {profile_arg}"
        if run_aws_command(cmd):
            results["success"].append(db_id)
        else:
            results["failed"].append(db_id)
    
    return results

def delete_s3_buckets(resource_ids, profile=None, dry_run=False):
    """Supprime les buckets S3"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} buckets S3 seraient supprimés")
        return {"success": resource_ids, "failed": []}
    
    for bucket_name in resource_ids:
        try:
            # 1. Vider le bucket d'abord (objets non versionnés)
            print(f"    📦 Vidage du bucket {bucket_name}...")
            empty_cmd = f"aws s3 rm s3://{bucket_name} --recursive {profile_arg}"
            run_aws_command(empty_cmd)
            
            # 2. Récupérer et supprimer toutes les versions d'objets
            print(f"    🔄 Suppression des versions...")
            list_versions_cmd = f"aws s3api list-object-versions --bucket {bucket_name} --output json {profile_arg}"
            versions_result = run_aws_command(list_versions_cmd)
            
            if versions_result:
                versions_data = json.loads(versions_result)
                
                # Supprimer les versions
                if versions_data.get('Versions'):
                    print(f"      • {len(versions_data['Versions'])} versions à supprimer")
                    for version in versions_data['Versions']:
                        delete_version_cmd = f"aws s3api delete-object --bucket {bucket_name} --key '{version['Key']}' --version-id {version['VersionId']} {profile_arg}"
                        run_aws_command(delete_version_cmd)
                
                # Supprimer les marqueurs de suppression
                if versions_data.get('DeleteMarkers'):
                    print(f"      • {len(versions_data['DeleteMarkers'])} marqueurs de suppression à nettoyer")
                    for marker in versions_data['DeleteMarkers']:
                        delete_marker_cmd = f"aws s3api delete-object --bucket {bucket_name} --key '{marker['Key']}' --version-id {marker['VersionId']} {profile_arg}"
                        run_aws_command(delete_marker_cmd)
            
            # 3. Supprimer le bucket maintenant qu'il est vide
            print(f"    🗑️  Suppression du bucket...")
            delete_cmd = f"aws s3api delete-bucket --bucket {bucket_name} {profile_arg}"
            if run_aws_command(delete_cmd):
                results["success"].append(bucket_name)
            else:
                results["failed"].append(bucket_name)
                
        except Exception as e:
            print(f"    ❌ Erreur lors de la suppression de {bucket_name}: {e}")
            results["failed"].append(bucket_name)
    
    return results

def delete_amis(region, resource_ids, profile=None, dry_run=False):
    """Supprime les AMIs (images)"""
    profile_arg = f"--profile {profile}" if profile else ""
    results = {"success": [], "failed": []}
    
    if dry_run:
        print(f"  🔍 DRY-RUN: {len(resource_ids)} AMIs seraient supprimées")
        return {"success": resource_ids, "failed": []}
    
    for ami_id in resource_ids:
        # D'abord récupérer les snapshots associés
        describe_cmd = f"aws ec2 describe-images --region {region} --image-ids {ami_id} --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' --output text {profile_arg}"
        snapshot_result = run_aws_command(describe_cmd)
        
        # Supprimer l'AMI
        deregister_cmd = f"aws ec2 deregister-image --region {region} --image-id {ami_id} {profile_arg}"
        if run_aws_command(deregister_cmd):
            results["success"].append(ami_id)
            
            # Supprimer les snapshots associés
            if snapshot_result and snapshot_result != "None":
                for snapshot_id in snapshot_result.split():
                    if snapshot_id and snapshot_id != "None":
                        snapshot_cmd = f"aws ec2 delete-snapshot --region {region} --snapshot-id {snapshot_id} {profile_arg}"
                        run_aws_command(snapshot_cmd)
        else:
            results["failed"].append(ami_id)
    
    return results

# =====================================================================
# CONFIGURATION DES FONCTIONS DE SUPPRESSION
# =====================================================================

DELETE_FUNCTIONS = {
    'ec2': delete_ec2_instances,
    'sg': delete_security_groups,
    'subnet': delete_subnets,
    'igw': delete_internet_gateways,
    'nat': delete_nat_gateways,
    'rt': delete_route_tables,
    'vpc': delete_vpcs,
    'elb': delete_classic_load_balancers,
    'elbv2': delete_load_balancers_v2,
    'rds': delete_rds_instances,
    's3': delete_s3_buckets,
    'ami': delete_amis
}

# Ordre de suppression (pour respecter les dépendances)
DELETION_ORDER = [
    'rds',      # RDS instances (pas de dépendances)
    'elbv2',    # Application/Network Load Balancers
    'elb',      # Classic Load Balancers
    'ec2',      # EC2 instances
    'nat',      # NAT Gateways
    'rt',       # Route Tables (non-main)
    'sg',       # Security Groups (non-default)
    'subnet',   # Subnets
    'igw',      # Internet Gateways
    'vpc',      # VPCs (en dernier)
    'ami',      # AMIs (peuvent être supprimées après EC2)
    's3'        # S3 Buckets (global)
]

def extract_resources_from_toml(toml_data, resource_types=None):
    """Extrait les ressources du fichier TOML"""
    resources_to_delete = {}
    
    # Filtrer les types de ressources
    types_to_process = resource_types if resource_types else DELETE_FUNCTIONS.keys()
    
    # Ressources régionales
    for key, section in toml_data.items():
        if key.startswith('region_'):
            region = key.replace('region_', '')
            
            for resource_type in types_to_process:
                if resource_type in section and 'resource_ids' in section[resource_type]:
                    resource_ids = section[resource_type]['resource_ids']
                    
                    if resource_ids:
                        if region not in resources_to_delete:
                            resources_to_delete[region] = {}
                        resources_to_delete[region][resource_type] = resource_ids
    
    # Ressources globales (S3)
    if 's3' in types_to_process and 'global_s3' in toml_data:
        if 'resource_ids' in toml_data['global_s3']:
            resource_ids = toml_data['global_s3']['resource_ids']
            if resource_ids:
                resources_to_delete['global'] = {'s3': resource_ids}
    
    return resources_to_delete

def show_summary(toml_data):
    """Affiche un résumé du fichier TOML"""
    metadata = toml_data.get('metadata', {})
    summary = toml_data.get('summary', {})
    
    print("📋 Résumé du fichier TOML:")
    print(f"  • Date de scan: {metadata.get('scan_date', 'Inconnue')}")
    print(f"  • Profil AWS: {metadata.get('profile', 'default')}")
    print(f"  • Régions scannées: {metadata.get('total_regions_scanned', 0)}")
    print(f"  • Types de ressources: {', '.join(metadata.get('resource_types_scanned', []))}")
    print(f"  • Total ressources: {summary.get('total_resources', 0)}")
    
    if summary.get('by_type'):
        print("  • Répartition par type:")
        for resource_type, count in summary['by_type'].items():
            print(f"    - {resource_type}: {count}")

def delete_resources(resources_to_delete, profile=None, dry_run=False):
    """Supprime les ressources selon l'ordre de dépendance"""
    total_stats = {"success": 0, "failed": 0, "total": 0}
    
    # Compter le total
    for region_data in resources_to_delete.values():
        for resource_list in region_data.values():
            total_stats["total"] += len(resource_list)
    
    print(f"\n🗑️  Suppression de {total_stats['total']} ressources...")
    
    # Supprimer dans l'ordre
    for resource_type in DELETION_ORDER:
        if resource_type not in DELETE_FUNCTIONS:
            continue
        
        delete_func = DELETE_FUNCTIONS[resource_type]
        found_resources = False
        
        for region, region_data in resources_to_delete.items():
            if resource_type not in region_data:
                continue
            
            resource_ids = region_data[resource_type]
            if not resource_ids:
                continue
            
            found_resources = True
            
            print(f"\n🔹 Suppression {resource_type} dans {region}:")
            for rid in resource_ids:
                print(f"    • {rid}")
            
            # Appeler la fonction de suppression appropriée
            if resource_type == 's3':
                # S3 est global
                results = delete_func(resource_ids, profile, dry_run)
            else:
                results = delete_func(region, resource_ids, profile, dry_run)
            
            # Compter les résultats
            total_stats["success"] += len(results["success"])
            total_stats["failed"] += len(results["failed"])
            
            # Afficher les résultats
            for success_id in results["success"]:
                print(f"    ✅ {success_id}")
            for failed_id in results["failed"]:
                print(f"    ❌ {failed_id}")
            
            # Attendre un peu entre les suppressions pour éviter les throttling
            if not dry_run and resource_ids:
                time.sleep(1)
        
        if found_resources and not dry_run:
            print(f"  ⏳ Attente pour les dépendances...")
            time.sleep(2)
    
    return total_stats

def main():
    parser = argparse.ArgumentParser(
        description='Supprime les ressources AWS listées dans un fichier TOML'
    )
    parser.add_argument(
        'toml_file',
        help='Fichier TOML contenant les ressources à supprimer'
    )
    parser.add_argument(
        '--profile',
        help='Profil AWS à utiliser',
        default=None
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Afficher ce qui serait supprimé sans le faire'
    )
    parser.add_argument(
        '--resource-types',
        nargs='+',
        help='Types de ressources à supprimer',
        choices=list(DELETE_FUNCTIONS.keys()),
        default=None
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Supprimer sans confirmation'
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
    
    # Extraire les ressources à supprimer
    print(f"\n🎯 Extraction des ressources à supprimer...")
    if args.resource_types:
        print(f"    Types sélectionnés: {', '.join(args.resource_types)}")
    
    resources_to_delete = extract_resources_from_toml(toml_data, args.resource_types)
    
    if not resources_to_delete:
        print("✅ Aucune ressource à supprimer trouvée")
        sys.exit(0)
    
    # Compter les ressources
    total_count = sum(len(resources) for region_data in resources_to_delete.values() 
                      for resources in region_data.values())
    
    print(f"⚠️  {total_count} ressources seront supprimées")
    
    # Demander confirmation si pas de force ou dry-run
    if not args.force and not args.dry_run:
        print("\n" + "="*70)
        print("⚠️  ATTENTION: Cette action va SUPPRIMER les ressources AWS!")
        print("   Cette action est IRRÉVERSIBLE!")
        print("   Les ressources seront supprimées dans l'ordre des dépendances")
        print("="*70)
        
        confirm = input("\nTaper 'DELETE-ALL-RESOURCES' pour confirmer: ")
        if confirm != 'DELETE-ALL-RESOURCES':
            print("❌ Opération annulée")
            sys.exit(0)
    
    # Supprimer les ressources
    stats = delete_resources(resources_to_delete, args.profile, args.dry_run)
    
    # Afficher les résultats
    print(f"\n📊 Résultats:")
    print(f"  • Total traité: {stats['total']}")
    print(f"  • Succès: {stats['success']}")
    print(f"  • Échecs: {stats['failed']}")
    
    if args.dry_run:
        print(f"\n🔍 Mode DRY-RUN: Aucune ressource n'a été réellement supprimée")
    else:
        print(f"\n✅ Suppression terminée!")
        if stats['failed'] > 0:
            print(f"⚠️  {stats['failed']} ressources n'ont pas pu être supprimées")
            print("   (vérifiez les dépendances ou les permissions)")

if __name__ == '__main__':
    main()