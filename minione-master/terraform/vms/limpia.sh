terraform destroy -auto-approve || echo "Destroy failed, continuing cleanup..."
rm -rf .terraform*
rm -f terraform.tfstate*                        
