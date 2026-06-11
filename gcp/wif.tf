# Create Workload Identity Pool Provider for GitHub and restrict access to GitHub organization
module "github-wif" {
  source     = "Cyclenerd/wif-github/google"
  version    = "~> 1.0.0"
  project_id = module.project.project_id
  # Restrict access to username or the name of a GitHub organization
  attribute_condition = "assertion.repository_owner == '${var.github_organization}'"
}

# Allow service account to login via WIF and only from GitHub repository
module "github-service-account" {
  source     = "Cyclenerd/wif-service-account/google"
  version    = "~> 1.0.0"
  project_id = module.project.project_id
  pool_name  = module.github-wif.pool_name
  account_id = module.service-account-github-actions.id
  repository = var.github_repository
  depends_on = [module.service-account-github-actions]
}
