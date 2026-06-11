output "region" {
  description = "The GCP region"
  value       = var.region
}

output "project" {
  description = "The GCP project ID"
  value       = module.project.project_id
}

# Get the Workload Identity Pool Provider resource name for GitHub Actions configuration
output "workload_identity_provider" {
  description = "The Workload Identity Provider resource name"
  value       = module.github-wif.provider_name
}

# The email address of the service account for GitHub Actions
output "workload_identity_service_account" {
  description = "The email address of the GitHub Actions service account"
  value       = module.service-account-github-actions.email
}

# The name of the VPC network created for the GitHub runners
output "network" {
  description = "The name of the VPC network"
  value       = module.vpc-github-runners.name
}

# The name of the subnet created for the GitHub runners
output "subnet" {
  description = "The name of the subnetwork"
  value       = values(module.vpc-github-runners.subnets)[0].name
}

# The email address of the service account for GitHub Actions Runners (Compute VMs)
output "service_account" {
  description = "The email address of the Compute VM GitHub Runners service account"
  value       = module.service-account-compute-vm-github-runners.email
}