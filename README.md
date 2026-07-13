# Self-Hosted GitHub Actions Runner on Google Cloud

[![Badge: Google Cloud](https://img.shields.io/badge/Google%20Cloud-4285F4.svg?logo=googlecloud&logoColor=white)](#readme)
[![Badge: GitHub](https://img.shields.io/badge/GitHub-181717.svg?logo=github&logoColor=white)](#readme)
[![Badge: Linux](https://img.shields.io/badge/Linux-FCC624.svg?logo=linux&logoColor=black)](#readme)
[![Badge: Ubuntu](https://img.shields.io/badge/Ubuntu-E95420.svg?logo=ubuntu&logoColor=white)](#readme)
[![Badge: GNU Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25.svg?logo=gnubash&logoColor=white)](#readme)

A GitHub Action to automatically create Google Compute Engine (GCE) VMs and register them as self-hosted GitHub Actions runners.

Launch a Google Compute Engine VM as a self-hosted GitHub Actions Runner just before your job starts.
Execute your workflow, and then automatically terminate the VM upon completion.
All within your GitHub Actions workflow.

This [GitHub Action](./action.sh) is written in Bash (Shell Script) and uses the
[`gcloud` CLI](https://cloud.google.com/sdk/gcloud) to **create** and **delete** the Compute Engine VM.
Everything was carefully documented and kept as simple as possible.
The aim is to enable quick and easy auditability of the code.

## How It Works

* **Create:** The action requests a GitHub Actions runner registration token, renders a
  [cloud-init](https://cloudinit.readthedocs.io/) configuration, and runs
  `gcloud compute instances create` with the configuration passed via the `user-data` instance metadata.
  On boot, the VM installs the GitHub Actions Runner and registers itself with your repository.
* **Delete:** The action runs `gcloud compute instances delete` to terminate the VM and then removes the
  corresponding self-hosted runner from your repository via the GitHub REST API.

## Cost Control and Predictability

> [!WARNING]
> **This project will incur Google Cloud costs.** Key cost considerations:
> - **More instances = higher costs**: Each workflow job creates a new instance
> - **Larger instances = higher costs**: More CPU cores and RAM increase hourly rates
> - **Malfunctioning workflows**: A GitHub workflow pipeline that doesn't function properly may run longer than intended, accumulating unexpected costs
> - **Failed termination**: Instances may not be terminated and deleted correctly due to errors or misconfigurations, resulting in ongoing charges
> - **Billing alerts recommended**: Set up [Google Cloud billing alerts and budgets](https://cloud.google.com/billing/docs/how-to/budgets) to monitor and control spending
> 
> **Use at your own risk.** Always monitor your Google Cloud billing dashboard and implement cost controls.

Despite these cost considerations, self-hosting on Google Cloud offers significant advantages:

* **Potentially Lower Costs for High Usage:** For organizations with consistently high CI/CD usage, self-hosting on Google Cloud can be significantly more cost-effective than paying for GitHub Actions minutes, especially for larger jobs or parallel execution.
* **No Usage Limits (Within Google Compute Engine (GCE) Quota):** You're not restricted by GitHub Actions usage limits. This is beneficial for large builds, extensive testing, or frequent deployments.

The following table provides a comparison of pricing between GitHub-managed Actions runners and Google Cloud with self-hosted runners (information provided without guarantee):

| Runner | [GitHub](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions) | [Google Cloud](https://gcloud-compute.com/instances.html) | Cost Saving | Cost Saving (%) |
|-----------------|--------------|----------------|----------------|---------|
| 2 Core (Intel)  | $0.36 USD/hr | $0.067 USD/hr  | $0.293 USD/hr  | 81.39 % |
| 4 Core (Intel)  | $0.72 USD/hr | $0.134 USD/hr  | $0.586 USD/hr  | 81.39 % |
| 8 Core (Intel)  | $1.32 USD/hr | $0.268 USD/hr  | $1.052 USD/hr  | 79.70 % |
| 16 Core (Intel) | $2.52 USD/hr | $0.5361 USD/hr | $1.9839 USD/hr | 78.73 % |
| 2 Core (Arm)    | $0.30 USD/hr | $0.0898 USD/hr | $0.2102 USD/hr | 70.07 % |
| 4 Core (Arm)    | $0.48 USD/hr | $0.1796 USD/hr | $0.3004 USD/hr | 62.58 % |
| 8 Core (Arm)    | $0.84 USD/hr | $0.3592 USD/hr | $0.4808 USD/hr | 57.24 % |
| 16 Core (Arm)   | $1.56 USD/hr | $0.7184 USD/hr | $0.8416 USD/hr | 53.95 % |

GitHub prices are based on January 1, 2026.
Google Cloud prices are based on the `us-central1` (Iowa, USA) region using E2 or C2A machine types without disk space.

Further savings are possible through Committed Use Discounts (CUD).

You can estimate costs using the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) or [gcloud-compute.com](https://gcloud-compute.com/).

## Project Philosophy

This GitHub Action and project allows you to create **ephemeral** and **isolated** runners for each job or workflow.
The core design principle is **"New Workflow, New VM"**.

*   **Isolation & Security:** Every job or workflow runs in a pristine environment. There is no cross-contamination or security risk from sharing runner instances across different repositories or workflows.
*   **Lifecycle:** This Action manages the full lifecycle: `Create` -> `Run` -> `Delete` within a single workflow run.
*   **Cattle, not Pets:** VMs are disposable resources. Long-running, shared resources or maintaining a pool of persistent runners is outside the scope of this project.

## Deployment to Google Cloud

Deploy the entire stack using Terraform:

```bash
git clone "https://github.com/Cyclenerd/gce-github-runner.git"
cd gce-github-runner/gcp
terraform init
terraform apply
```

**What this does:**
*   **Provisions Identity:** Creates Google Cloud Service Account with least-privilege permissions.
*   **Provisions Network:** Creates VPC and Subnet for the GCE VM-based GitHub Actions runners.

For detailed deployment instructions and configuration options, see [gcp/README.md](gcp/README.md).

## Usage

Prepare your workflow for Google Cloud self-hosted runners:

1. **Create a fine-grained GitHub Personal Access Token (PAT)** with "Read and write" access to "Administration"
    * [GitHub](https://github.com/settings/personal-access-tokens) → Settings → Developer Settings → Personal access tokens → Fine-grained personal access tokens
    * [More Help](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
1. **Set up Google Cloud authentication** for the `gcloud` CLI in your workflow. The recommended approach is
   [Workload Identity Federation](https://github.com/google-github-actions/auth#preferred-direct-workload-identity-federation) via
   [`google-github-actions/auth`](https://github.com/google-github-actions/auth), which avoids long-lived service account keys.
   The authenticated identity needs the **Compute Instance Admin (v1)** role (`roles/compute.instanceAdmin.v1`)
   and, if a custom service account is attached to the VM, the **Service Account User** role (`roles/iam.serviceAccountUser`).
1. **Add the GitHub PAT as a repository secret:**
    * GitHub → Select repository → Settings → Secrets and variables → Actions → New repository secret
        * `PERSONAL_ACCESS_TOKEN`: Your GitHub Personal Access Token
    * [More Help](https://docs.github.com/actions/security-guides/encrypted-secrets)
1. **Create or adapt your workflow** following the example below.

## Example

Example GitHub Actions Workflow:

```yml
name: "Example"
on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write # required for Workload Identity Federation

env:
  PROJECT: my-gcp-project

jobs:
  create-runner:
    name: Create Google Cloud runner
    runs-on: ubuntu-latest
    outputs:
      label: ${{ steps.create-gcloud-runner.outputs.label }}
      vm_name: ${{ steps.create-gcloud-runner.outputs.vm_name }}
      zone: ${{ steps.create-gcloud-runner.outputs.zone }}
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v3

      - name: Create runner
        id: create-gcloud-runner
        uses: Cyclenerd/gce-github-runner@v1
        with:
          mode: create
          github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          project: ${{ env.PROJECT }}
          zone: "europe-west1-b, us-central1-a, us-west1-b"
          machine_type: e2-medium
          image_family: ubuntu-2404-lts-amd64
          image_project: ubuntu-os-cloud

  do-the-job:
    name: Do the job on the runner
    needs: create-runner # required to start the main job when the runner is ready
    runs-on: ${{ needs.create-runner.outputs.label }} # run the job on the newly created runner
    steps:
      - name: Hello from runner
        run: |
          echo "Hello from $(hostname)"

  delete-runner:
    name: Delete Google Cloud runner
    needs:
      - create-runner # required to get output from the create-runner job
      - do-the-job # required to wait when the main job is done
    runs-on: ubuntu-latest
    if: ${{ always() }} # required to stop the runner even if the error happened in the previous jobs
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v3

      - name: Delete runner
        uses: Cyclenerd/gce-github-runner@v1
        with:
          mode: delete
          github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          project: ${{ env.PROJECT }}
          name: ${{ needs.create-runner.outputs.label }}
```

## Inputs

> [!IMPORTANT]
> Google Cloud Compute Engine billing is per-second (with a one-minute minimum) for most machine types.
> The VM created by this action is deleted automatically in `delete` mode.

> [!CAUTION]
> The runner has been tested with the Google-provided Ubuntu (`ubuntu-os-cloud`) image family `ubuntu-2404-lts-amd64` and `ubuntu-2404-lts-arm64`,
> which ship with [cloud-init](https://cloudinit.readthedocs.io/) preinstalled. Cloud-init is required because the
> startup configuration is delivered via the `user-data` instance metadata key.

| Name                  | Required | Description | Default |
|-----------------------|----------|-------------|---------|
| `delete_wait`         |   | Wait up to `delete_wait` retries (10 sec each) to delete the VM via the `gcloud` CLI. | `360` (1 hour) |
| `disk_size`           |   | Boot disk size in GB. | `40` |
| `disk_type`           |   | Boot disk type (`pd-standard`, `pd-balanced`, `pd-ssd`). | `pd-balanced` |
| `enable_external_ip`  |   | Attach an external (public) IP to the VM. If `false`, the VM needs another route to the internet (e.g. Cloud NAT) because the GitHub API requires outbound access. | `true` |
| `github_token`        | ✓ (always) | Fine-grained GitHub Personal Access Token (PAT) with 'Read and write' access to 'Administration' assigned. |  |
| `image`               |   | Name of a specific Compute Engine image. If set, takes precedence over `image_family`. | `null` |
| `image_family`        |   | Image family to create the VM from. | `ubuntu-2404-lts-amd64` |
| `image_project`       |   | Project against which `image`/`image_family` is resolved. | `ubuntu-os-cloud` |
| `machine_type`        |   | Machine type the VM should be created with. | `e2-medium` |
| `max_run_duration`    |   | Maximum run duration before the VM is automatically terminated. Accepts the gcloud duration format (e.g. `4h`, `30m`, `14400s`) or a plain number of seconds. Safety limit to avoid orphaned VMs if `delete` mode never runs. | `4h` |
| `mode`                | ✓ (always) | Choose either `create` to create a new GitHub Actions Runner or `delete` to delete a previously created one. |  |
| `name`                | ✓ (mode `delete`, optional for mode `create`) | The name for the VM and label for the GitHub Actions Runner (RFC1035: lowercase letters, digits and hyphens; must start with a letter). | `gh-runner-[RANDOM-INT]` |
| `network`             |   | Name of the VPC network. | `default` |
| `pre_runner_script`   |   | Specifies bash commands to run before the GitHub Actions Runner starts. Useful for installing dependencies with apt-get, dnf, etc. |  |
| `project`             |   | Google Cloud project ID. If omitted, the default project configured in the `gcloud` CLI is used. | `null` |
| `runner_dir`          |   | GitHub Actions Runner installation directory (created automatically; no trailing slash). | `/actions-runner` |
| `runner_version`      |   | GitHub Actions Runner version (omit "v"; e.g., "2.321.0"). "latest" installs the latest version. "skip" skips the installation. | `latest` |
| `runner_wait`         |   | Wait up to `runner_wait` retries (10 sec each) for runner registration. | `60` (10 min) |
| `service_account`     |   | Service account email to attach to the VM. If omitted, the project default Compute Engine service account is used. | `null` |
| `scopes`              |   | Comma separated list of access scopes for the attached service account. | `cloud-platform` |
| `tags`                |   | Comma separated list of network tags to apply to the VM (e.g. for firewall rules). | `null` |
| `vm_wait`             |   | Wait up to `vm_wait` retries (10 sec each) for the VM to start running. | `30` (5 min) |
| `zone`                |   | Compute Engine zone or comma-separated list of zones to create the VM in (e.g. `europe-west1-b, us-central1-a`). The action loops through the list and uses the first zone where VM creation succeeds. | `europe-west1-b` |

## Outputs

| Name      | Description |
|-----------|-------------|
| `label`   | This label uniquely identifies a GitHub Actions runner, used both to specify which runner a job should execute on via the `runs-on` property and to delete the runner when it's no longer needed. |
| `vm_name` | This is the Compute Engine VM name of the runner, used to delete the VM when the runner is no longer required. |
| `zone`    | The Compute Engine zone where the VM was successfully created. |

## Snippets

The following `gcloud` CLI commands can help you find the required input values.

### Projects

**List projects:**

```bash
gcloud projects list
```

### Zones

**List zones:**

```bash
gcloud compute zones list --format="table(name,region,status)"
```

### Machine Types

**List machine types in a zone:**

```bash
gcloud compute machine-types list --zones="europe-west1-b" --format="table(name,guestCpus,memoryMb)"
```

### Images

**List image families for a project:**

```bash
gcloud compute images list --project="ubuntu-os-cloud" --format="table(family,name)" --filter="family:ubuntu"
```

**Create a custom image** from an existing VM (clean cloud-init first):

```bash
# On the VM:
sudo cloud-init clean --logs --machine-id --seed --configs all

# From your workstation:
gcloud compute images create "github-runner-image" \
  --source-disk="[SOURCE-VM-NAME]" \
  --source-disk-zone="europe-west1-b"
```

### Network

**List networks:**

```bash
gcloud compute networks list
```

### Service Accounts

**List service accounts:**

```bash
gcloud iam service-accounts list
```

## Security

> We recommend that you only use self-hosted runners with private repositories.
> This is because forks of your public repository can potentially run dangerous code on your self-hosted runner machine by creating a pull request that executes the code in a workflow.

For security considerations, see the [GitHub documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security).

## Contributing

Have a patch that will benefit this project?
Awesome! Follow these steps to have it accepted.

1. Please read [how to contribute](CONTRIBUTING.md).
1. Fork this Git repository and make your changes.
1. Create a Pull Request.
1. Incorporate review feedback to your changes.
1. Accepted!

## Credits

This GitHub Action is based on the idea and implementation of [Volodymyr Machula](https://github.com/machulav) for [AWS EC2 runner](https://github.com/machulav/ec2-github-runner).

### Related Projects

If this project fits your needs, you might also be interested in these related projects of mine:

* [**hcloud-github-runner**](https://github.com/Cyclenerd/hcloud-github-runner) —
  The original project this one is based on. A lightweight, Bash-only GitHub Action that launches an on-demand
  self-hosted runner on [Hetzner Cloud](https://www.hetzner.com/cloud/) using the Hetzner Cloud API.
  It follows the same `create` / `run` / `delete` lifecycle and has been tested with Debian, Ubuntu,
  Fedora, Rocky Linux and openSUSE on both x86 and Arm.
* [**google-cloud-github-runner**](https://github.com/Cyclenerd/google-cloud-github-runner) —
  A more advanced, cloud-native alternative for Google Cloud. Instead of wiring up `create` and `delete`
  jobs in every workflow, it deploys a GitHub App and a Cloud Run service (via Terraform) that listens for
  `workflow_job` webhooks and spins ephemeral GCE instances from instance templates up and down automatically.
  Acts as a drop-in replacement: just use `runs-on: gcp-ubuntu-latest`. Supports both repository- and
  organization-level runners on x86 and Arm.

## License

All files in this repository are under the [Apache License, Version 2.0](LICENSE) unless noted otherwise.
