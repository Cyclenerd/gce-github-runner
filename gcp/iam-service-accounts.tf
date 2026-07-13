# https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/v56.2.0/modules/iam-service-account/README.md

# Service Account for GitHub Actions
module "service-account-github-actions" {
  source       = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v56.2.0"
  project_id   = module.project.project_id
  name         = "gce-github-runner-actions"
  display_name = "GitHub ${var.github_repository} - GitHub Actions (Terraform managed)"
  iam_project_roles = {
    (module.project.project_id) = [
      "roles/compute.instanceAdmin.v1",
    ]
  }
}

# Service Account for GitHub Actions Runners (Compute Engine VMs)
module "service-account-compute-vm-github-runners" {
  source       = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v56.2.0"
  project_id   = module.project.project_id
  name         = "gce-github-runner-vms"
  display_name = "Compute VMs - GitHub Actions Runners (Terraform managed)"
  iam = {
    "roles/iam.serviceAccountUser" = [
      module.service-account-github-actions.iam_email
    ]
  }
  iam_project_roles = {
    (module.project.project_id) = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
    ]
  }
}
