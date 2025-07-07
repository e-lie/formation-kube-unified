#!/bin/bash
set -e

echo "🔍 Validating Terraform configurations..."

for env in dev staging prod; do
    echo "Checking $env environment..."
    cd "environments/$env"
    
    # Format check
    terraform fmt -check
    
    # Validation
    terraform validate
    
    cd ../..
done

echo "✅ All environments validated successfully!"