# Create Workload Identity Pool Provider for GitHub and restrict access to GitHub organization
module "github-wif" {
  source     = "Cyclenerd/wif-github/google"
  version    = "~> 1.0.0"
  project_id = module.project.project_id
  attribute_mapping = {
    "google.subject" : "assertion.sub"               # repo:octo-org/octo-repo:environment:prod
    "attribute.repository" : "assertion.repository", # octo-org/octo-repo
    "attribute.ref" : "assertion.ref",               # refs/heads/main
    "attribute.repo_ref" : "\"repo:\" + assertion.repository + \":ref:\" + assertion.ref"
  }
  # Restrict access to username or the name of a GitHub organization
  attribute_condition = "assertion.repository_owner == '${var.github_organization}'"
}

# Allow service account to login via WIF and only from GitHub repository
resource "google_service_account_iam_binding" "wif-binding" {
  service_account_id = module.service-account-github-actions.id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    var.github_ref != null ? "principalSet://iam.googleapis.com/${module.github-wif.pool_name}/attribute.repo_ref/repo:${var.github_repository}:ref:${var.github_ref}" : "principalSet://iam.googleapis.com/${module.github-wif.pool_name}/attribute.repository/${var.github_repository}"
  ]
  depends_on = [module.service-account-github-actions]
}
