# Google Cloud APIs to enable for the project
variable "apis" {
  description = "List of Google Cloud APIs to be enable"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "storage.googleapis.com",
  ]
}

# Google Cloud project ID where resources will be created
variable "project_id" {
  description = "Existing Google Cloud project ID"
  type        = string
  nullable    = false

  # https://cloud.google.com/resource-manager/docs/creating-managing-projects#before_you_begin
  validation {
    # Must be 6 to 30 characters in length.
    # Can only contain lowercase letters, numbers, and hyphens.
    # Must start with a letter.
    # Cannot end with a hyphen.
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Invalid Google Cloud project ID!"
  }
}

# Google Cloud region for deploying resources
variable "region" {
  description = "Google Cloud region name"
  type        = string
  default     = "us-central1"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][-a-z]+[0-9]$", var.region))
    error_message = "Invalid Google Cloud region name!"
  }

}

# GitHub organization name (or username)
variable "github_organization" {
  description = "GitHub organization name or username to restrict Workload Identity Federation access"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.github_organization) >= 1 && length(var.github_organization) <= 39 && can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$", var.github_organization))
    error_message = "Invalid GitHub organization name! Must be between 1 and 39 characters, contain only alphanumeric characters or single hyphens, and cannot start or end with a hyphen."
  }
}

# GitHub repository name (owner/repository)
variable "github_repository" {
  description = "GitHub repository name (e.g. 'owner/repository') to restrict Workload Identity Federation access"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.github_repository) >= 3 && length(var.github_repository) <= 140 && can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*/[a-zA-Z0-9._-]+$", var.github_repository))
    error_message = "Invalid GitHub repository name! Must be in 'owner/repository' format. Owner name must be 1 to 39 characters (alphanumeric/hyphens), and repository name must be 1 to 100 characters (alphanumeric/hyphens/underscores/periods)."
  }
}

# IPv4 CIDR range for GitHub Runner VMs
variable "github_runners_internal_cidr" {
  description = "IPv4 CIDR range for GitHub Runner VMs"
  type        = string
  default     = "192.168.1.0/24"
  nullable    = false

  validation {
    condition     = can(cidrhost(var.github_runners_internal_cidr, 0))
    error_message = "Invalid IPv4 CIDR block format!"
  }
}
