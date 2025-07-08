#!/usr/bin/env python3
"""
Script pour lister toutes les ressources AWS importantes et exporter en TOML
Support: EC2, VPC, Subnets, Security Groups, Load Balancers, etc.
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
        if e.stderr:
            print(f"   Erreur: {e.stderr}")
        return None

def flatten_aws_response(aws_response):
    """Aplatit la réponse AWS (gère les listes imbriquées)"""
    flattened = []
    for item in aws_response:
        if isinstance(item, list):
            flattened.extend(item)
        else:
            flattened.append(item)
    return flattened

def get_regions(profile=None):
    """Récupère la liste des régions AWS"""
    profile_arg = f"--profile {profile}" if profile else ""
    cmd = f"aws ec2 describe-regions --query 'Regions[].RegionName' --output json {profile_arg}"
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

# =====================================================================
# FONCTIONS POUR CHAQUE TYPE DE RESSOURCE
# =====================================================================

def get_ec2_instances(region, profile=None):
    """Récupère les instances EC2"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    # Récupérer les IDs
    cmd = f"aws ec2 describe-instances --region {region} --query 'Reservations[*].Instances[*].InstanceId' --output json {profile_arg}"
    result = run_aws_command(cmd)
    
    if not result:
        return []
    
    instance_ids = flatten_aws_response(json.loads(result))
    if not instance_ids:
        return []
    
    # Récupérer les détails
    query = "Reservations[*].Instances[*].{Id:InstanceId,State:State.Name,Type:InstanceType,VpcId:VpcId}"
    details_cmd = f'aws ec2 describe-instances --region {region} --instance-ids {" ".join(instance_ids)} --query "{query}" --output json {profile_arg}'
    
    details_result = run_aws_command(details_cmd)
    if details_result:
        return flatten_aws_response(json.loads(details_result))
    
    return [{"Id": iid, "State": "unknown", "Type": "unknown", "VpcId": ""} for iid in instance_ids]

def get_vpcs(region, profile=None):
    """Récupère les VPCs"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "Vpcs[*].{Id:VpcId,State:State,IsDefault:IsDefault,CidrBlock:CidrBlock}"
    cmd = f'aws ec2 describe-vpcs --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        vpcs = json.loads(result)
        # Filtrer le VPC par défaut si demandé
        return [vpc for vpc in vpcs if not vpc.get('IsDefault', False)]
    return []

def get_subnets(region, profile=None):
    """Récupère les subnets"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "Subnets[*].{Id:SubnetId,VpcId:VpcId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,State:State}"
    cmd = f'aws ec2 describe-subnets --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_security_groups(region, profile=None):
    """Récupère les security groups"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "SecurityGroups[*].{Id:GroupId,Name:GroupName,VpcId:VpcId,Description:Description}"
    cmd = f'aws ec2 describe-security-groups --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        sgs = json.loads(result)
        # Filtrer les groupes "default" si demandé
        return [sg for sg in sgs if sg.get('Name') != 'default']
    return []

def get_load_balancers_v2(region, profile=None):
    """Récupère les Application/Network Load Balancers (ELBv2)"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "LoadBalancers[*].{Id:LoadBalancerArn,Name:LoadBalancerName,Type:Type,State:State.Code,VpcId:VpcId,Scheme:Scheme}"
    cmd = f'aws elbv2 describe-load-balancers --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_classic_load_balancers(region, profile=None):
    """Récupère les Classic Load Balancers (ELB)"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "LoadBalancerDescriptions[*].{Id:LoadBalancerName,Name:LoadBalancerName,VpcId:VPCId,Scheme:Scheme,State:to_string('active')}"
    cmd = f'aws elb describe-load-balancers --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_internet_gateways(region, profile=None):
    """Récupère les Internet Gateways"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "InternetGateways[*].{Id:InternetGatewayId,State:to_string('available'),VpcId:Attachments[0].VpcId}"
    cmd = f'aws ec2 describe-internet-gateways --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_nat_gateways(region, profile=None):
    """Récupère les NAT Gateways"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "NatGateways[*].{Id:NatGatewayId,State:State,VpcId:VpcId,SubnetId:SubnetId}"
    cmd = f'aws ec2 describe-nat-gateways --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_route_tables(region, profile=None):
    """Récupère les Route Tables"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "RouteTables[*].{Id:RouteTableId,VpcId:VpcId,IsMain:Associations[?Main].Main|[0]}"
    cmd = f'aws ec2 describe-route-tables --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        route_tables = json.loads(result)
        # Filtrer les route tables principales si demandé
        return [rt for rt in route_tables if not rt.get('IsMain', False)]
    return []

def get_rds_instances(region, profile=None):
    """Récupère les instances RDS"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "DBInstances[*].{Id:DBInstanceIdentifier,Engine:Engine,State:DBInstanceStatus,VpcId:DBSubnetGroup.VpcId,MultiAZ:MultiAZ}"
    cmd = f'aws rds describe-db-instances --region {region} --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_s3_buckets(profile=None):
    """Récupère les buckets S3 (global)"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "Buckets[*].{Id:Name,Name:Name,CreationDate:CreationDate}"
    cmd = f'aws s3api list-buckets --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

def get_amis(region, profile=None):
    """Récupère les AMIs (images) créées par l'utilisateur"""
    profile_arg = f"--profile {profile}" if profile else ""
    
    query = "Images[*].{Id:ImageId,Name:Name,State:State,CreationDate:CreationDate,OwnerId:OwnerId,Public:Public}"
    cmd = f'aws ec2 describe-images --region {region} --owners self --query "{query}" --output json {profile_arg}'
    
    result = run_aws_command(cmd)
    if result:
        return json.loads(result)
    return []

# =====================================================================
# CONFIGURATION DES TYPES DE RESSOURCES
# =====================================================================

RESOURCE_TYPES = {
    'ec2': {
        'name': 'EC2 Instances',
        'function': get_ec2_instances,
        'regional': True,
        'id_field': 'Id'
    },
    'vpc': {
        'name': 'VPCs',
        'function': get_vpcs,
        'regional': True,
        'id_field': 'Id'
    },
    'subnet': {
        'name': 'Subnets',
        'function': get_subnets,
        'regional': True,
        'id_field': 'Id'
    },
    'sg': {
        'name': 'Security Groups',
        'function': get_security_groups,
        'regional': True,
        'id_field': 'Id'
    },
    'elb': {
        'name': 'Classic Load Balancers',
        'function': get_classic_load_balancers,
        'regional': True,
        'id_field': 'Id'
    },
    'elbv2': {
        'name': 'Application/Network Load Balancers',
        'function': get_load_balancers_v2,
        'regional': True,
        'id_field': 'Id'
    },
    'igw': {
        'name': 'Internet Gateways',
        'function': get_internet_gateways,
        'regional': True,
        'id_field': 'Id'
    },
    'nat': {
        'name': 'NAT Gateways',
        'function': get_nat_gateways,
        'regional': True,
        'id_field': 'Id'
    },
    'rt': {
        'name': 'Route Tables',
        'function': get_route_tables,
        'regional': True,
        'id_field': 'Id'
    },
    'rds': {
        'name': 'RDS Instances',
        'function': get_rds_instances,
        'regional': True,
        'id_field': 'Id'
    },
    's3': {
        'name': 'S3 Buckets',
        'function': get_s3_buckets,
        'regional': False,
        'id_field': 'Id'
    },
    'ami': {
        'name': 'AMIs (Images)',
        'function': get_amis,
        'regional': True,
        'id_field': 'Id'
    }
}

def scan_resources(profile=None, regions=None, resource_types=None):
    """Scanne toutes les ressources demandées"""
    
    print("🔍 Scan des ressources AWS...")
    
    # Obtenir les régions à scanner
    if regions:
        target_regions = regions
    else:
        print("📍 Récupération de la liste des régions...")
        target_regions = get_regions(profile)
        if not target_regions:
            print("❌ Impossible de récupérer les régions")
            return None
    
    # Types de ressources à scanner
    if resource_types:
        types_to_scan = {k: v for k, v in RESOURCE_TYPES.items() if k in resource_types}
    else:
        types_to_scan = RESOURCE_TYPES
    
    # Structure pour le TOML
    toml_data = {
        'metadata': {
            'scan_date': datetime.now().isoformat(),
            'profile': profile if profile else 'default',
            'total_regions_scanned': len(target_regions),
            'regions_scanned': target_regions,
            'resource_types_scanned': list(types_to_scan.keys())
        },
        'summary': {
            'total_resources': 0,
            'by_type': {},
            'by_region': {}
        }
    }
    
    # Scanner les ressources globales (S3)
    for resource_type, config in types_to_scan.items():
        if not config['regional']:
            print(f"  🌍 Scan global: {config['name']}")
            resources = config['function'](profile)
            
            if resources:
                resource_list = [res[config['id_field']] for res in resources]
                resource_details = {res[config['id_field']]: res for res in resources}
                
                toml_data[f'global_{resource_type}'] = {
                    'resource_count': len(resources),
                    'resource_ids': resource_list,
                    'resources': resource_details
                }
                
                toml_data['summary']['total_resources'] += len(resources)
                toml_data['summary']['by_type'][resource_type] = len(resources)
                
                print(f"    ✅ {len(resources)} {config['name']} trouvées")
            else:
                print(f"    ⭕ Aucune {config['name']}")
    
    # Scanner chaque région pour les ressources régionales
    for region in target_regions:
        print(f"  📍 Scan région: {region}")
        region_data = {}
        region_total = 0
        
        for resource_type, config in types_to_scan.items():
            if config['regional']:
                print(f"    🔍 {config['name']}...")
                
                resources = config['function'](region, profile)
                
                if resources:
                    resource_list = [res[config['id_field']] for res in resources]
                    resource_details = {res[config['id_field']]: res for res in resources}
                    
                    region_data[resource_type] = {
                        'resource_count': len(resources),
                        'resource_ids': resource_list,
                        'resources': resource_details
                    }
                    
                    region_total += len(resources)
                    
                    if resource_type not in toml_data['summary']['by_type']:
                        toml_data['summary']['by_type'][resource_type] = 0
                    toml_data['summary']['by_type'][resource_type] += len(resources)
                    
                    print(f"      ✅ {len(resources)} trouvées")
                else:
                    print(f"      ⭕ Aucune")
                    region_data[resource_type] = {
                        'resource_count': 0,
                        'resource_ids': [],
                        'resources': {}
                    }
        
        if region_data:
            toml_data[f'region_{region}'] = region_data
            toml_data['summary']['by_region'][region] = region_total
            toml_data['summary']['total_resources'] += region_total
    
    return toml_data

def main():
    parser = argparse.ArgumentParser(
        description='Scanne les ressources AWS et exporte en TOML'
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
        '--resource-types',
        nargs='+',
        help='Types de ressources à scanner',
        choices=list(RESOURCE_TYPES.keys()),
        default=None
    )
    parser.add_argument(
        '--output',
        help='Fichier de sortie TOML',
        default=None
    )
    parser.add_argument(
        '--list-types',
        action='store_true',
        help='Lister les types de ressources disponibles'
    )
    parser.add_argument(
        '--check-cli',
        action='store_true',
        help='Vérifier la configuration AWS CLI'
    )
    
    args = parser.parse_args()
    
    # Lister les types disponibles
    if args.list_types:
        print("\n📋 Types de ressources disponibles:")
        print("-" * 50)
        for key, config in RESOURCE_TYPES.items():
            scope = "🌍 Global" if not config['regional'] else "📍 Régional"
            print(f"  {key:<8} - {config['name']:<30} ({scope})")
        print()
        return
    
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
        return
    
    # Vérifier que toml est installé
    try:
        import toml
    except ImportError:
        print("❌ Le module 'toml' n'est pas installé")
        print("   Installation: pip install toml")
        sys.exit(1)
    
    # Lancer le scan
    toml_data = scan_resources(args.profile, args.regions, args.resource_types)
    
    if not toml_data:
        sys.exit(1)
    
    # Générer le fichier TOML
    if not args.output:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        resource_suffix = "_".join(args.resource_types) if args.resource_types else "all"
        args.output = f"aws_resources_{resource_suffix}_{timestamp}.toml"
    
    try:
        with open(args.output, 'w', encoding='utf-8') as f:
            toml.dump(toml_data, f)
        
        print(f"\n✅ Fichier TOML généré: {args.output}")
        print(f"📊 Résumé: {toml_data['summary']['total_resources']} ressources")
        
        # Afficher le résumé par type
        if toml_data['summary']['by_type']:
            print("\n📈 Répartition par type:")
            for resource_type, count in toml_data['summary']['by_type'].items():
                type_name = RESOURCE_TYPES[resource_type]['name']
                print(f"  • {type_name}: {count}")
        
        print("\n🎉 Scan terminé avec succès!")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'écriture du fichier TOML: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()