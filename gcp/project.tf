# Configure the Google Cloud project and enable required APIs
# https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/v56.2.0/modules/project/README.md
module "project" {
  source        = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project?ref=v56.2.0"
  name          = var.project_id
  project_reuse = {}
  services      = var.apis
}
