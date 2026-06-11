# Google Cloud Blueprint (Working Example for a Repository)

This directory provides a blueprint and working example of Terraform Infrastructure as Code (IaC) for setting up Google Cloud Platform (GCP) resources for a single GitHub GCE Actions Runner repository.

## Prerequisites

- **Terraform >= 1.13.0** installed and available in your PATH.
- **Google Cloud CLI (gcloud)** installed and configured with appropriate permissions.
- **Google Cloud Project** with an active billing account.
- **GitHub Organization or User** for which the runners will be created.
- **GitHub Repository** for which the runners will be created.

## Project

A separate Google Cloud project is recommended for the GitHub GCE Actions Runners.

Create a Google Cloud project with a attached billing account.

### IAM Roles

The **Owner role** (`roles/owner`) is the easiest option for deploying this project. If the Owner role is not possible (e.g., in enterprise environments with restricted permissions), the following specific roles must be assigned to your Google account on project level:

| Role ID | Role Name | Purpose |
|---------|-----------|---------|
| `roles/compute.admin` | Compute Admin | Manage Compute Engine resources (VMs, templates, images) |
| `roles/iam.roleViewer` | Role Viewer | Provides read access to all custom roles in the project. |
| `roles/iam.serviceAccountAdmin` | Service Account Admin | Create and manage service accounts. |
| `roles/iam.serviceAccountUser` | Service Account User | Run operations as the service account. |
| `roles/iam.workloadIdentityPoolAdmin` | IAM Workload Identity Pool Admin | Full rights to create and manage workload identity pools. |
| `roles/logging.admin` | Logging Admin | Access to all logging permissions, and dependent permissions. |
| `roles/monitoring.admin` | Monitoring Admin | All monitoring permissions. |
| `roles/resourcemanager.projectIamAdmin` | Project IAM Admin | Access and administer a project IAM policies. |
| `roles/serviceusage.serviceUsageAdmin` | Service Usage Admin | Enable and disable Google Cloud APIs |

### Login

Authenticate with Google Cloud and set the quota project:

```bash
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
```

Set the quota project and project where the resources will be created:

```bash
gcloud projects list
export GOOGLE_CLOUD_PROJECT="your-project-id"
gcloud config set project "$GOOGLE_CLOUD_PROJECT"
gcloud auth application-default set-quota-project "$GOOGLE_CLOUD_PROJECT"
```

## Setup via Terraform

The majority of the required services and resources are configured via Terraform Infrastructure as Code (IaC).

### 1. Configure

Navigate to the `gcp` directory (the directory of this README) and create the variables file:

```bash
cd gcp
```

Create a `terraform.tfvars` file with your configuration.

Google Cloud project ID:

```bash
printf 'project_id = "%s"\n' "$GOOGLE_CLOUD_PROJECT" > terraform.tfvars
```

GitHub organization name or username:

```bash
printf 'github_organization = "%s"\n' "[GITHUB ORGANIZATION]" > terraform.tfvars
```

GitHub repository name:

```bash
printf 'github_repository = "%s"\n' "[GITHUB OWNER]/[GITHUB REPOSITORY]" > terraform.tfvars
```

(Optional) Google Cloud region:

```bash
echo "region = \"us-central1\"" >> terraform.tfvars
```

For all available variables, see [variables.tf](variables.tf).

### Apply

Initialize Terraform:

```bash
terraform init
```

Apply the configuration:

```bash
terraform apply
```

* Review the plan when prompted.
* Type `yes` and press Enter to confirm.

## Cleanup / Destroy

To destroy all resources created by Terraform, run:

```bash
terraform destroy
```

<!-- BEGIN_TF_DOCS -->
## Providers

No providers.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apis"></a> [apis](#input\_apis) | List of Google Cloud APIs to be enable | `list(string)` | <pre>[<br/>  "cloudresourcemanager.googleapis.com",<br/>  "compute.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "logging.googleapis.com",<br/>  "storage.googleapis.com"<br/>]</pre> | no |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | GitHub organization name or username to restrict Workload Identity Federation access | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (e.g. 'owner/repository') to restrict Workload Identity Federation access | `string` | n/a | yes |
| <a name="input_github_runners_internal_cidr"></a> [github\_runners\_internal\_cidr](#input\_github\_runners\_internal\_cidr) | IPv4 CIDR range for GitHub Runner VMs | `string` | `"192.168.1.0/24"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Existing Google Cloud project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Google Cloud region name | `string` | `"us-central1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network"></a> [network](#output\_network) | The name of the VPC network |
| <a name="output_project"></a> [project](#output\_project) | The GCP project ID |
| <a name="output_region"></a> [region](#output\_region) | The GCP region |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | The email address of the Compute VM GitHub Runners service account |
| <a name="output_subnet"></a> [subnet](#output\_subnet) | The name of the subnetwork |
| <a name="output_workload_identity_provider"></a> [workload\_identity\_provider](#output\_workload\_identity\_provider) | The Workload Identity Provider resource name |
| <a name="output_workload_identity_service_account"></a> [workload\_identity\_service\_account](#output\_workload\_identity\_service\_account) | The email address of the GitHub Actions service account |
<!-- END_TF_DOCS -->
