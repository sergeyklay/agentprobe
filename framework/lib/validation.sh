#!/usr/bin/env bash
# validation.sh - Validate experiment config and environment
#
# Provides: validate_config, validate_environment

# Check experiment.yaml has required fields and referenced files exist.
# Usage: validate_config experiment.yaml experiment_dir
validate_config() {
  local config_file="$1"
  local experiment_dir="$2"
  local errors=0

  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Config not found: $config_file" >&2
    return 1
  fi

  # Required scalar fields
  local required=(".name" ".project.local_path" ".project.base_commit"
                   ".agent.cli" ".agent.model" ".runs.per_condition"
                   ".task.prompt_file")

  for field in "${required[@]}"; do
    local val
    val=$(yq "$field" "$config_file" 2>/dev/null)
    if [[ -z "$val" || "$val" == "null" ]]; then
      echo "ERROR: Missing required field: $field" >&2
      ((errors++))
    fi
  done

  # At least 2 conditions
  local num_conditions
  num_conditions=$(yq '.conditions | length' "$config_file" 2>/dev/null)
  if [[ "${num_conditions:-0}" -lt 2 ]]; then
    echo "ERROR: At least 2 conditions required, found: ${num_conditions:-0}" >&2
    ((errors++))
  fi

  # Condition setup scripts exist
  for ((i = 0; i < num_conditions; i++)); do
    local setup
    setup=$(yq ".conditions[$i].setup" "$config_file")
    if [[ ! -f "$experiment_dir/$setup" ]]; then
      echo "ERROR: Setup script not found: $experiment_dir/$setup" >&2
      ((errors++))
    fi
  done

  # Task prompt file exists
  local prompt_file
  prompt_file=$(yq '.task.prompt_file' "$config_file")
  if [[ ! -f "$experiment_dir/$prompt_file" ]]; then
    echo "ERROR: Task prompt not found: $experiment_dir/$prompt_file" >&2
    ((errors++))
  fi

  return $errors
}

# Check that required CLI tools and the project repo are available.
# Usage: validate_environment experiment.yaml
validate_environment() {
  local config_file="$1"
  local errors=0

  # Agent CLI
  local agent_cli
  agent_cli=$(yq '.agent.cli' "$config_file")
  if ! command -v "$agent_cli" &>/dev/null; then
    echo "ERROR: Agent CLI not found: $agent_cli" >&2
    ((errors++))
  else
    echo "  $agent_cli: $(command -v "$agent_cli")"
  fi

  # Project directory
  local project_dir
  project_dir=$(eval echo "$(yq '.project.local_path' "$config_file")")
  if [[ ! -d "$project_dir/.git" ]]; then
    echo "ERROR: Project is not a git repo: $project_dir" >&2
    ((errors++))
  else
    echo "  project: $project_dir"
  fi

  # Required tools
  for tool in jq yq python3 git; do
    if ! command -v "$tool" &>/dev/null; then
      echo "ERROR: Required tool not found: $tool" >&2
      ((errors++))
    fi
  done

  # Node/pnpm (if typescript project)
  for tool in node pnpm; do
    local path
    path=$(command -v "$tool" 2>/dev/null || true)
    if [[ -n "$path" ]]; then
      echo "  $tool: $path ($($tool --version 2>/dev/null))"
    fi
  done

  return $errors
}
