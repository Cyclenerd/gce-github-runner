#!/usr/bin/env bash

# Copyright 2026 Nils Knieling. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Create an on-demand self-hosted GitHub Actions Runner in Google Cloud
# using the gcloud CLI to start and delete the Google Compute Engine VM.
# https://cloud.google.com/sdk/gcloud/reference/compute/instances/create
# https://cloud.google.com/sdk/gcloud/reference/compute/instances/delete

# Function to exit the script with a failure message
function exit_with_failure() {
	echo >&2 "FAILURE: $1"  # Print error message to stderr
	exit 1
}

# Define required commands
MY_COMMANDS=(
	base64
	curl
	envsubst
	gcloud
	jq
)
# Check if required commands are available
for MY_COMMAND in "${MY_COMMANDS[@]}"; do
	if ! command -v "$MY_COMMAND" >/dev/null 2>&1; then
		exit_with_failure "The command '$MY_COMMAND' was not found. Please install it."
	fi
done

# Check if files exist
MY_FILES=(
	"cloud-init.template.yml"
	"install.sh"
)
for MY_FILE in "${MY_FILES[@]}"; do
	if [[ ! -f "$MY_FILE" ]]; then
		exit_with_failure "The file '$MY_FILE' was not found!"
	fi
done

# Retry wait time in seconds
WAIT_SEC=10

#
# INPUT
#

# GitHub Actions inputs
# https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions#inputs
# When you specify an input, GitHub creates an environment variable for the input with the name INPUT_<VARIABLE_NAME>.

# Set maximum retries * WAIT_SEC (10 sec) for Compute Engine VM deletion via the gcloud CLI (default: 360 [1 hour])
MY_DELETE_WAIT=${INPUT_DELETE_WAIT:-360}
if [[ ! "$MY_DELETE_WAIT" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum retries for Compute Engine VM deletion must be an integer!"
fi

# Boot disk size in GB (default: 40)
MY_DISK_SIZE=${INPUT_DISK_SIZE:-40}
if [[ ! "$MY_DISK_SIZE" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The boot disk size must be an integer (GB)!"
fi

# Boot disk type (default: pd-balanced)
MY_DISK_TYPE=${INPUT_DISK_TYPE:-"pd-balanced"}
if [[ ! "$MY_DISK_TYPE" =~ ^[a-z0-9-]{1,63}$ ]]; then
	exit_with_failure "'$MY_DISK_TYPE' is not a valid disk type!"
fi

# Attach external (public) IP (default: true)
MY_ENABLE_EXTERNAL_IP=${INPUT_ENABLE_EXTERNAL_IP:-"true"}
if [[ "$MY_ENABLE_EXTERNAL_IP" != "true" && "$MY_ENABLE_EXTERNAL_IP" != "false" ]]; then
	exit_with_failure "Enable external IP must be 'true' or 'false'."
fi

# Set the GitHub Personal Access Token (PAT).
MY_GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
if [[ -z "$MY_GITHUB_TOKEN" ]]; then
	exit_with_failure "GitHub Personal Access Token (PAT) token is required!"
fi

# Set the GitHub repository name (automatically set in GitHub Actions workflows).
# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables
MY_GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
if [[ -z "$MY_GITHUB_REPOSITORY" ]]; then
	exit_with_failure "GitHub repository is required!"
fi

# Set the specific image (default: null, i.e. use image family)
MY_IMAGE=${INPUT_IMAGE:-"null"}
if [[ "$MY_IMAGE" != "null" && ! "$MY_IMAGE" =~ ^[a-zA-Z0-9._-]{1,63}$ ]]; then
	exit_with_failure "'$MY_IMAGE' is not a valid image name!"
fi

# Set the image family (default: ubuntu-2404-lts-amd64)
MY_IMAGE_FAMILY=${INPUT_IMAGE_FAMILY:-"ubuntu-2404-lts-amd64"}
if [[ ! "$MY_IMAGE_FAMILY" =~ ^[a-zA-Z0-9._-]{1,63}$ ]]; then
	exit_with_failure "'$MY_IMAGE_FAMILY' is not a valid image family name!"
fi

# Set the image project (default: ubuntu-os-cloud)
MY_IMAGE_PROJECT=${INPUT_IMAGE_PROJECT:-"ubuntu-os-cloud"}
if [[ ! "$MY_IMAGE_PROJECT" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
	exit_with_failure "'$MY_IMAGE_PROJECT' is not a valid image project ID!"
fi
if [[ "$MY_IMAGE_PROJECT" != "ubuntu-os-cloud" ]]; then
	echo "WARNING: The image project is not 'ubuntu-os-cloud'. Cloud-init is needed and this project is only tested with Ubuntu."
fi

# Set the machine type (default: e2-medium)
MY_MACHINE_TYPE=${INPUT_MACHINE_TYPE:-"e2-medium"}
if [[ ! "$MY_MACHINE_TYPE" =~ ^[a-z0-9-]{1,63}$ ]]; then
	exit_with_failure "'$MY_MACHINE_TYPE' is not a valid machine type!"
fi

# Specify the mode (default: create):
# - create : Create a new runner
# - delete : Delete the previously created runner
MY_MODE=${INPUT_MODE:-"create"}
if [[ "$MY_MODE" != "create" && "$MY_MODE" != "delete" ]]; then
	exit_with_failure "Mode must be 'create' or 'delete'."
fi

# Set the name of the VM (default: gh-runner-$RANDOM)
# Compute Engine VM names must conform to RFC1035.
MY_NAME=${INPUT_NAME:-"gh-runner-$RANDOM"}
if [[ ! "$MY_NAME" =~ ^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
	exit_with_failure "'$MY_NAME' is not a valid Compute Engine VM name (RFC1035: lowercase letters, digits and hyphens; must start with a letter)!"
fi

# Set the VPC network (default: default)
MY_NETWORK=${INPUT_NETWORK:-"default"}
if [[ ! "$MY_NETWORK" =~ ^[a-z0-9-]{1,63}$ ]]; then
	exit_with_failure "'$MY_NETWORK' is not a valid network name!"
fi

# Set bash commands to run before the runner starts.
MY_PRE_RUNNER_SCRIPT=${INPUT_PRE_RUNNER_SCRIPT:-""}

# Set the Google Cloud project (default: null, i.e. use gcloud default project)
MY_PROJECT=${INPUT_PROJECT:-"null"}
if [[ "$MY_PROJECT" != "null" && ! "$MY_PROJECT" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
	exit_with_failure "'$MY_PROJECT' is not a valid Google Cloud project ID!"
fi

# Set the GitHub Actions Runner installation directory (default: /actions-runner)
MY_RUNNER_DIR=${INPUT_RUNNER_DIR:-"/actions-runner"}
if [[ ! "$MY_RUNNER_DIR" =~ ^/([^/]+/)*[^/]+$ ]]; then
	exit_with_failure "'$MY_RUNNER_DIR' is not a valid absolute directory path without a trailing slash!"
fi

# Set the GitHub Actions Runner version (default: latest)
# Releases: https://github.com/actions/runner/releases
MY_RUNNER_VERSION=${INPUT_RUNNER_VERSION:-"latest"}
if [[ "$MY_RUNNER_VERSION" != "latest" && "$MY_RUNNER_VERSION" != "skip" && ! "$MY_RUNNER_VERSION" =~ ^[0-9.]{1,63}$ ]]; then
	exit_with_failure "'$MY_RUNNER_VERSION' is not a valid GitHub Actions Runner version! Enter 'latest', 'skip' or the version without 'v'."
fi

# Set maximum retries * WAIT_SEC (10 sec) for GitHub Actions Runner registration (default: 60 [10 min])
MY_RUNNER_WAIT=${INPUT_RUNNER_WAIT:-"60"}
if [[ ! "$MY_RUNNER_WAIT" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum wait time (retries) for GitHub Actions Runner registration must be an integer!"
fi

# Set the service account email (default: null)
MY_SERVICE_ACCOUNT=${INPUT_SERVICE_ACCOUNT:-"null"}

# Set the access scopes (default: cloud-platform)
MY_SCOPES=${INPUT_SCOPES:-"cloud-platform"}
# Set the network tags (default: null)
MY_TAGS=${INPUT_TAGS:-"null"}

# Set maximum retries * WAIT_SEC (10 sec) for the Compute Engine VM to start (default: 30 [5 min])
MY_VM_WAIT=${INPUT_VM_WAIT:-"30"}
if [[ ! "$MY_VM_WAIT" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum wait time (retries) for a running Compute Engine VM must be an integer!"
fi

# Set the subnetwork (default: null)
# Accepts a single subnet name or a comma-separated list (one per zone).
MY_SUBNET=${INPUT_SUBNET:-"null"}
IFS=',' read -ra SUBNETS <<< "$MY_SUBNET"
for i in "${!SUBNETS[@]}"; do
	SUBNETS[i]=$(echo "${SUBNETS[i]}" | xargs)
	if [[ "${SUBNETS[i]}" != "null" && ! "${SUBNETS[i]}" =~ ^[a-z0-9-]{1,63}$ ]]; then
		exit_with_failure "'${SUBNETS[i]}' is not a valid subnetwork name!"
	fi
done

# Set the Compute Engine zone (default: europe-west1-b)
MY_ZONE=${INPUT_ZONE:-"europe-west1-b"}
IFS=',' read -ra ZONES <<< "$MY_ZONE"
for i in "${!ZONES[@]}"; do
	ZONES[i]=$(echo "${ZONES[i]}" | xargs)
	if [[ ! "${ZONES[i]}" =~ ^[a-z][-a-z]+[0-9]-[a-z]$ ]]; then
		exit_with_failure "'${ZONES[i]}' is not a valid Compute Engine zone!"
	fi
done


# Set the maximum run duration before the VM is automatically terminated (default: 4h = 14400s)
# Accepts the gcloud duration format, e.g. '4h', '30m', '14400s' or a plain number of seconds.
# https://cloud.google.com/compute/docs/instances/limit-vm-runtime
MY_MAX_RUN_DURATION=${INPUT_MAX_RUN_DURATION:-"4h"}
if [[ ! "$MY_MAX_RUN_DURATION" =~ ^[0-9]+[smhd]?$ ]]; then
	exit_with_failure "'$MY_MAX_RUN_DURATION' is not a valid max run duration! Use a number of seconds or a value like '4h', '30m', '14400s'."
fi

# Build common gcloud flags (project)
GCLOUD_PROJECT_FLAG=()
if [[ "$MY_PROJECT" != "null" ]]; then
	GCLOUD_PROJECT_FLAG=(--project "$MY_PROJECT")
fi

#
# DELETE
#

if [[ "$MY_MODE" == "delete" ]]; then
	# Find which zone the VM actually exists in.
	VM_ZONE=""
	for ZONE in "${ZONES[@]}"; do
		if gcloud compute instances describe "$MY_NAME" \
			--zone "$ZONE" \
			"${GCLOUD_PROJECT_FLAG[@]}" \
			--format="value(name)" \
			--quiet >/dev/null 2>&1; then
			VM_ZONE="$ZONE"
			break
		fi
	done

	if [[ -z "$VM_ZONE" ]]; then
		echo "Compute Engine VM '$MY_NAME' does not exist in any of the specified zones."
		DELETED="true"
	else
		# Delete the Compute Engine VM via the gcloud CLI.
		# https://cloud.google.com/sdk/gcloud/reference/compute/instances/delete
		echo "Delete Compute Engine VM '$MY_NAME' in zone '$VM_ZONE'..."
		MAX_RETRIES=$MY_DELETE_WAIT
		RETRY_COUNT=0
		DELETED="false"
		while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
			if gcloud compute instances delete "$MY_NAME" \
				--zone "$VM_ZONE" \
				"${GCLOUD_PROJECT_FLAG[@]}" \
				--quiet; then
				echo "Compute Engine VM deleted successfully."
				DELETED="true"
				break
			fi

			# If the VM no longer exists, treat as success.
			if ! gcloud compute instances describe "$MY_NAME" \
				--zone "$VM_ZONE" \
				"${GCLOUD_PROJECT_FLAG[@]}" \
				--format="value(name)" \
				--quiet >/dev/null 2>&1; then
				echo "Compute Engine VM '$MY_NAME' does not exist (already deleted)."
				DELETED="true"
				break
			fi

			RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter
			echo "Failed to delete VM. Wait $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
			sleep "$WAIT_SEC"
		done
	fi

	if [[ "$DELETED" != "true" ]]; then
		exit_with_failure "Failed to delete Compute Engine VM! Please check manually."
	fi

	# List self-hosted runners for repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-self-hosted-runners-for-a-repository
	echo "List self-hosted runners..."
	curl -L \
		--fail-with-body \
		-o "github-runners.json" \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners" \
		|| exit_with_failure "Failed to list GitHub Actions runners from repository!"

	MY_GITHUB_RUNNER_ID=$(jq -er ".runners[] | select(.name == \"$MY_NAME\") | .id" < "github-runners.json")
	if [[ ! "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
		exit_with_failure "Failed to get ID of the GitHub Actions Runner!"
	fi

	# Delete a self-hosted runner from repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#delete-a-self-hosted-runner-from-a-repository
	echo "Delete GitHub Actions Runner..."
	curl -L \
		-X DELETE \
		--fail-with-body \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/${MY_GITHUB_RUNNER_ID}" \
		|| exit_with_failure "Failed to delete GitHub Actions Runner from repository! Please delete manually: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners"
	echo "GitHub Actions Runner deleted successfully."
	echo
	echo "The Compute Engine VM and its associated GitHub Actions Runner have been deleted successfully."
	# Add GitHub Action job summary
	# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#adding-a-job-summary
	echo "The Compute Engine VM and its associated GitHub Actions Runner have been deleted successfully 🗑️" >> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

#
# CREATE
#

# Create GitHub Actions registration token for registering a self-hosted runner to a repository
# https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository
echo "Create GitHub Actions Runner registration token..."
curl -L \
	-X "POST" \
	--fail-with-body \
	-o "registration-token.json" \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/registration-token" \
	|| exit_with_failure "Failed to retrieve GitHub Actions Runner registration token!"

# Read the GitHub Runner registration token from a file (assuming valid JSON)
MY_GITHUB_RUNNER_REGISTRATION_TOKEN=$(jq -er '.token' < "registration-token.json")

# Encode the contents of the "install.sh" and runner script into base64
# BSD
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "freebsd"* ]]; then
	MY_INSTALL_SH_BASE64=$(base64 < "install.sh")
	MY_PRE_RUNNER_SCRIPT_BASE64=$(echo "$MY_PRE_RUNNER_SCRIPT" | base64)
# GNU Core tools
else
	MY_INSTALL_SH_BASE64=$(base64 --wrap=0 < "install.sh")
	MY_PRE_RUNNER_SCRIPT_BASE64=$(echo "$MY_PRE_RUNNER_SCRIPT" | base64 --wrap=0)
fi

# Export environment variables for use in the cloud-init template
export MY_GITHUB_REPOSITORY
export MY_GITHUB_RUNNER_REGISTRATION_TOKEN
export MY_INSTALL_SH_BASE64
export MY_NAME
export MY_PRE_RUNNER_SCRIPT_BASE64
export MY_RUNNER_DIR
export MY_RUNNER_VERSION
# Substitute environment variables in the cloud-init template and create the final cloud-init configuration
envsubst < cloud-init.template.yml > cloud-init.yml

# Create the Compute Engine VM via the gcloud CLI.
VM_CREATED="false"
MY_ZONE_SUCCESS=""
for ZONE_INDEX in "${!ZONES[@]}"; do
	ZONE="${ZONES[ZONE_INDEX]}"

	# Determine the subnet for this zone:
	# - If only one subnet is given it is used for all zones.
	# - If multiple subnets are given they are mapped 1-to-1 to the zones.
	# - If no subnet is given (null) the flag is omitted and GCP picks automatically.
	if [[ ${#SUBNETS[@]} -eq 1 ]]; then
		CURRENT_SUBNET="${SUBNETS[0]}"
	else
		CURRENT_SUBNET="${SUBNETS[ZONE_INDEX]:-null}"
	fi

	# Assemble gcloud compute instances create arguments.
	# https://cloud.google.com/sdk/gcloud/reference/compute/instances/create
	echo "Generate VM configuration for zone '$ZONE'..."
	GCLOUD_CREATE_ARGS=(
		"$MY_NAME"
		--zone "$ZONE"
		--machine-type "$MY_MACHINE_TYPE"
		--boot-disk-size "${MY_DISK_SIZE}GB"
		--boot-disk-type "$MY_DISK_TYPE"
		--network "$MY_NETWORK"
		--labels "type=github-runner,gh-runner=true"
		--metadata "vmDnsSetting=ZonalOnly,block-project-ssh-keys=true"
		--metadata-from-file "user-data=cloud-init.yml"
		--max-run-duration "$MY_MAX_RUN_DURATION"
		--instance-termination-action "DELETE"
		--quiet
	)
	GCLOUD_CREATE_ARGS+=("${GCLOUD_PROJECT_FLAG[@]}")

	# Image: prefer an explicit image, otherwise use the image family.
	if [[ "$MY_IMAGE" != "null" ]]; then
		GCLOUD_CREATE_ARGS+=(--image "$MY_IMAGE" --image-project "$MY_IMAGE_PROJECT")
	else
		GCLOUD_CREATE_ARGS+=(--image-family "$MY_IMAGE_FAMILY" --image-project "$MY_IMAGE_PROJECT")
	fi

	# External IP configuration.
	if [[ "$MY_ENABLE_EXTERNAL_IP" == "false" ]]; then
		GCLOUD_CREATE_ARGS+=(--no-address)
	fi

	# Network tags.
	if [[ "$MY_TAGS" != "null" ]]; then
		GCLOUD_CREATE_ARGS+=(--tags "$MY_TAGS")
	fi

	# Service account and scopes.
	if [[ "$MY_SERVICE_ACCOUNT" != "null" ]]; then
		GCLOUD_CREATE_ARGS+=(--service-account "$MY_SERVICE_ACCOUNT")
	fi
	if [[ -n "$MY_SCOPES" && "$MY_SCOPES" != "null" ]]; then
		GCLOUD_CREATE_ARGS+=(--scopes "$MY_SCOPES")
	fi

	# Subnet.
	if [[ "$CURRENT_SUBNET" != "null" ]]; then
		GCLOUD_CREATE_ARGS+=(--subnet "$CURRENT_SUBNET")
	fi

	echo "Create Compute Engine VM '$MY_NAME' in zone '$ZONE'..."
	if gcloud compute instances create "${GCLOUD_CREATE_ARGS[@]}"; then
		echo "Compute Engine VM created successfully in zone '$ZONE'."
		VM_CREATED="true"
		MY_ZONE_SUCCESS="$ZONE"
		break
	else
		echo "WARNING: Failed to create Compute Engine VM in zone '$ZONE'. Trying next zone..."
	fi
done

if [[ "$VM_CREATED" != "true" ]]; then
	exit_with_failure "Failed to create Compute Engine VM in any of the specified zones!"
fi

# Set GitHub Action output
# https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
{
	echo "label=$MY_NAME"
	echo "zone=$MY_ZONE_SUCCESS"
} >> "$GITHUB_OUTPUT"

# Wait for the VM to reach the RUNNING status.
MAX_RETRIES=$MY_VM_WAIT
RETRY_COUNT=0
MY_VM_STATUS=""
echo "Wait for Compute Engine VM..."
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
	# https://cloud.google.com/sdk/gcloud/reference/compute/instances/describe
	MY_VM_STATUS=$(gcloud compute instances describe "$MY_NAME" \
		--zone "$MY_ZONE_SUCCESS" \
		"${GCLOUD_PROJECT_FLAG[@]}" \
		--format="value(status)" \
		--quiet 2>/dev/null)

	if [[ "$MY_VM_STATUS" == "RUNNING" ]]; then
		echo "Compute Engine VM is running."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter
	echo "VM is not running yet (status: ${MY_VM_STATUS:-unknown}). Waiting $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
	sleep "$WAIT_SEC"
done
if [[ "$MY_VM_STATUS" != "RUNNING" ]]; then
	exit_with_failure "Failed to start Compute Engine VM! Please check manually."
fi

# Wait for GitHub Actions Runner registration
MAX_RETRIES=$MY_RUNNER_WAIT
RETRY_COUNT=0
MY_GITHUB_RUNNER_ID=""
echo "Wait for GitHub Actions Runner registration..."
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
	# List self-hosted runners for repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-self-hosted-runners-for-a-repository
	curl -L -s \
		-o "github-runners.json" \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners" \
		|| exit_with_failure "Failed to list GitHub Actions runners from repository!"

	MY_GITHUB_RUNNER_ID=$(jq -er ".runners[] | select(.name == \"$MY_NAME\") | .id" < "github-runners.json")
	if [[ "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
		echo "GitHub Actions Runner registered."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter
	echo "GitHub Actions Runner is not yet registered. Wait $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
	sleep "$WAIT_SEC"
done
if [[ ! "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
	exit_with_failure "GitHub Actions Runner is not registered. Please check installation manually."
fi

echo
echo "The Compute Engine VM and its associated GitHub Actions Runner are ready for use."
echo "Runner: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}"
# Add GitHub Action job summary
# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#adding-a-job-summary
echo "The Compute Engine VM and its associated [GitHub Actions Runner](https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}) are ready for use 🚀" >> "$GITHUB_STEP_SUMMARY"
exit 0
