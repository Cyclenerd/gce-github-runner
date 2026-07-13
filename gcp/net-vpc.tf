# VPC for GitHub Actions Runners
# https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/v56.2.0/modules/net-vpc/README.md
module "vpc-github-runners" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=v56.2.0"
  project_id  = module.project.project_id
  name        = "vpc-gce-github-runners"
  description = "VPC for Google Compute Engine GitHub Actions Runners (Terraform-managed)"
  subnets = [
    for region, cidr in var.github_runners_internal_cidr : {
      ip_cidr_range = cidr
      name          = "subnet-gce-github-runners-${local.region_shortnames[region]}"
      region        = region
      description   = "Subnet for GitHub Actions Runners in ${region} (Terraform-managed)"
    }
  ]
}

# Firewall rules for GitHub Actions Runners
# https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v56.2.0/modules/net-vpc-firewall
module "firewall-github-runners" {
  source               = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v56.2.0"
  project_id           = module.project.project_id
  network              = module.vpc-github-runners.name
  default_rules_config = { disabled = true }
  ingress_rules = {
    allow-ssh-from-iap = {
      description   = "Enable SSH from IAP (Terraform-managed)"
      source_ranges = ["35.235.240.0/20"]
      rules         = [{ protocol = "tcp", ports = [22] }]
    }
  }
}
