# shellcheck shell=bash
# ==============================================================================
#  ec2.zsh - EC2 Instance Connect helpers
# ==============================================================================
#  Installed to ~/.config/zsh/ec2.zsh and sourced by ~/.zshrc. Written in the
#  common subset of Bash and Zsh, so ShellCheck can lint it as Bash.
#
#  Commands
#    ec2_connect    [instance-id]                            open an SSH session
#    ec2_copy_file  [instance-id] [remote-path] [local-path] download a file
#    ec2_paste_file [instance-id] [local-path] [remote-path] upload a file
#
#  Missing arguments are asked for. Each command:
#    1. looks up the availability zone and IP address of the instance with the
#       active AWS profile (AWS_PROFILE, e.g. after `aws sso login`);
#    2. picks the SSH key: the local key pair when it is on disk, otherwise a
#       private key stored in 1Password (loaded into a temporary ssh-agent,
#       never written to disk);
#    3. pushes the public key with EC2 Instance Connect (valid for 60 seconds)
#       and connects.
#
#  Region: EC2_CONNECT_REGION, then AWS_REGION, AWS_DEFAULT_REGION, then the
#  region of the active AWS profile.
#
#  Environment (set these in ~/.config/zsh/local.zsh)
#    EC2_CONNECT_OS_USER          login user         (default: ubuntu)
#    EC2_CONNECT_ADDRESS          private or public  (default: private)
#    EC2_CONNECT_REGION           region override
#    EC2_CONNECT_PRIVATE_KEY      local private key  (default: ~/.ssh/ec2_instance_connect)
#    EC2_CONNECT_PUBLIC_KEY       local public key   (default: <private key>.pub)
#    EC2_CONNECT_1PASSWORD_ITEM   1Password item that holds the private key
#    EC2_CONNECT_1PASSWORD_VAULT  its vault          (default: Private)
#    EC2_CONNECT_1PASSWORD_FIELD  its field          (default: private key)
#
#  Requires: aws (v2), ssh, scp. The 1Password fallback also needs op.
# ==============================================================================

# ------------------------------------------------------------------------------
#  Private helpers
# ------------------------------------------------------------------------------

# _ec2_ask <variable> <question> - read one line into the named variable.
_ec2_ask() {
  printf '%s ' "$2"
  IFS= read -r "${1?}"
}

# _ec2_run <connect|copy|paste> [instance-id] [path] [path]
# Runs in a subshell, so the EXIT trap and the temporary ssh-agent never touch
# the interactive shell.
_ec2_run() (
  mode=$1
  instance_id=${2:-}
  first_path=${3:-}
  second_path=${4:-}

  os_user=${EC2_CONNECT_OS_USER:-ubuntu}
  address_kind=${EC2_CONNECT_ADDRESS:-private}
  private_key=${EC2_CONNECT_PRIVATE_KEY:-${HOME}/.ssh/ec2_instance_connect}
  public_key=${EC2_CONNECT_PUBLIC_KEY:-${private_key}.pub}
  op_item=${EC2_CONNECT_1PASSWORD_ITEM:-}
  op_vault=${EC2_CONNECT_1PASSWORD_VAULT:-Private}
  op_field=${EC2_CONNECT_1PASSWORD_FIELD:-private key}

  key_dir=''
  agent_started=false
  ssh_options=(-o IdentitiesOnly=yes)

  # Stop the temporary agent and remove temporary files on any exit.
  # shellcheck disable=SC2329
  _ec2_cleanup() {
    if "${agent_started}"; then ssh-agent -k >/dev/null 2>&1; fi
    if [[ -n ${key_dir} ]]; then command rm -rf "${key_dir}"; fi
  }
  trap _ec2_cleanup EXIT

  # --- Arguments --------------------------------------------------------------
  if [[ -z ${instance_id} ]]; then _ec2_ask instance_id 'Instance ID:'; fi
  if [[ -z ${instance_id} ]]; then
    echo 'Error: an instance ID is required.' >&2
    exit 1
  fi
  case "${mode}" in
    copy)
      if [[ -z ${first_path} ]]; then _ec2_ask first_path 'Remote file to download:'; fi
      if [[ -z ${second_path} ]]; then _ec2_ask second_path 'Local destination:'; fi
      ;;
    paste)
      if [[ -z ${first_path} ]]; then _ec2_ask first_path 'Local file to upload:'; fi
      if [[ -z ${second_path} ]]; then _ec2_ask second_path 'Remote destination:'; fi
      ;;
  esac
  if [[ ${mode} != connect && (-z ${first_path} || -z ${second_path}) ]]; then
    echo 'Error: a source and a destination path are required.' >&2
    exit 1
  fi

  # --- 1. Instance lookup -----------------------------------------------------
  region=${EC2_CONNECT_REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}
  if [[ -z ${region} ]]; then region=$(aws configure get region 2>/dev/null || true); fi
  if [[ -z ${region} ]]; then
    echo 'Error: no AWS region. Set EC2_CONNECT_REGION or AWS_REGION, or add a region to the AWS profile.' >&2
    exit 1
  fi

  if ! details=$(aws ec2 describe-instances \
    --region "${region}" \
    --instance-ids "${instance_id}" \
    --query 'Reservations[0].Instances[0].[Placement.AvailabilityZone,PrivateIpAddress,PublicIpAddress]' \
    --output text); then
    echo "Error: could not describe ${instance_id} in ${region}. Is the AWS session still valid?" >&2
    exit 1
  fi
  read -r availability_zone private_ip public_ip <<<"${details}"

  if [[ ${address_kind} == public ]]; then address=${public_ip:-}; else address=${private_ip:-}; fi
  if [[ -z ${availability_zone:-} || ${availability_zone} == None || -z ${address} || ${address} == None ]]; then
    echo "Error: ${instance_id} has no availability zone or no ${address_kind} IP address in ${region}." >&2
    exit 1
  fi
  echo "Instance ${instance_id} in ${availability_zone}, ${address_kind} address ${address}"

  # --- 2. SSH key: local key pair first, 1Password as the fallback --------------
  if [[ -f ${private_key} ]]; then
    identity=${private_key}
    if [[ ! -f ${public_key} ]]; then
      key_dir=$(mktemp -d)
      public_key="${key_dir}/identity.pub"
      ssh-keygen -y -f "${private_key}" >"${public_key}" || exit 1
    fi
  elif [[ -n ${op_item} ]]; then
    if ! command -v op >/dev/null 2>&1; then
      echo "Error: the 1Password CLI (op) is required to read ${op_item}." >&2
      exit 1
    fi
    echo 'Loading the private key from 1Password into a temporary agent...'
    key_dir=$(mktemp -d)
    agent_env=$(ssh-agent -s)
    eval "${agent_env}" >/dev/null
    agent_started=true
    if ! op read "op://${op_vault}/${op_item}/${op_field}?ssh-format=openssh" | ssh-add - >/dev/null 2>&1; then
      echo 'Error: could not load the private key from 1Password.' >&2
      exit 1
    fi
    public_key="${key_dir}/identity.pub"
    ssh-add -L >"${public_key}"
    # OpenSSH selects the matching agent key through its public key file. The
    # agent is named explicitly because an IdentityAgent line in ~/.ssh/config
    # would otherwise take precedence over SSH_AUTH_SOCK.
    identity=${public_key}
    ssh_options+=(-o "IdentityAgent=${SSH_AUTH_SOCK}")
  else
    echo 'Error: no SSH key for EC2 Instance Connect.' >&2
    echo "Create ${private_key} (ssh-keygen -t ed25519 -f ${private_key}) or set EC2_CONNECT_1PASSWORD_ITEM." >&2
    exit 1
  fi

  # --- 3. Push the key and connect --------------------------------------------
  if ! aws ec2-instance-connect send-ssh-public-key \
    --region "${region}" \
    --availability-zone "${availability_zone}" \
    --instance-id "${instance_id}" \
    --instance-os-user "${os_user}" \
    --ssh-public-key "file://${public_key}" >/dev/null; then
    echo 'Error: could not send the SSH public key to the instance.' >&2
    exit 1
  fi

  case "${mode}" in
    connect) ssh "${ssh_options[@]}" -i "${identity}" -l "${os_user}" "${address}" ;;
    copy) scp "${ssh_options[@]}" -i "${identity}" "${os_user}@${address}:${first_path}" "${second_path}" ;;
    paste) scp "${ssh_options[@]}" -i "${identity}" "${first_path}" "${os_user}@${address}:${second_path}" ;;
  esac
)

# ------------------------------------------------------------------------------
#  Commands
# ------------------------------------------------------------------------------

# ec2_connect [instance-id] - open an SSH session on an instance.
ec2_connect() { _ec2_run connect "$@"; }

# ec2_copy_file [instance-id] [remote-path] [local-path] - download a file.
ec2_copy_file() { _ec2_run copy "$@"; }

# ec2_paste_file [instance-id] [local-path] [remote-path] - upload a file.
ec2_paste_file() { _ec2_run paste "$@"; }
