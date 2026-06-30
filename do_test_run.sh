#!/usr/bin/env bash

# Stop at first error
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DOCKER_IMAGE_TAG="example_algorithm_phase-1"
CONTAINER_NAME="example_algorithm_phase-1_container"

INPUT_DIR="${SCRIPT_DIR}/test/input"
OUTPUT_DIR="${SCRIPT_DIR}/test/output"

# This can be any open port
PORT=37847

# Staging directories are bind-mounted into the container as /input and /output.
# They start empty and are provisioned with hard-linked input files right before each
# invocation.
STAGING_INPUT_DIR="${SCRIPT_DIR}/test/.staging_input"
STAGING_OUTPUT_DIR="${SCRIPT_DIR}/test/.staging_output"

main() {
  setup

  build_container
  start_container
  
  check_health

  provision "interf0"
  invoke
  collect_output "interf0"
  log "Wrote results to ${OUTPUT_DIR}/interf0"

  provision "interf1"
  invoke
  collect_output "interf1"
  log "Wrote results to ${OUTPUT_DIR}/interf1"

  log "Save this image for uploading via ./do_save.sh"
}

setup() {
  # This allows for the Docker user to read
  chmod -R -f o+rX "$INPUT_DIR" "${SCRIPT_DIR}/model"

  # Disables prompotional logs from Docker
  export DOCKER_CLI_HINTS=false

  # Initialize
  LOG_LINES_SHOWN=0

  DOCKER_NOOP_VOLUME="${DOCKER_IMAGE_TAG}-volume"
  
  # Create empty staging directories for /input and /output bind mounts
  rm -rf "$STAGING_INPUT_DIR" "$STAGING_OUTPUT_DIR"
  mkdir -m o+rwX "$STAGING_INPUT_DIR"
  mkdir -m o+rwX "$STAGING_OUTPUT_DIR"

  docker volume create "$DOCKER_NOOP_VOLUME" > /dev/null
}

cleanup() {
    log "Cleanup ..."
    # Ensure permissions are set correctly on the output
    # This allows the host user (e.g. you) to access and handle these files

    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    log "Container stopped"

    # Remove staging directories and noop volume
    rm -rf "$STAGING_INPUT_DIR" "$STAGING_OUTPUT_DIR"
    docker volume rm "$DOCKER_NOOP_VOLUME" > /dev/null 2>&1 || true
}

trap cleanup EXIT

build_container() {
  log "(Re)build the container"
  source "${SCRIPT_DIR}/do_build.sh"

  log "Verifying container labels"
  API_METHOD=$(docker inspect --format='{{index .Config.Labels "org.grand-challenge.api-method"}}' "$DOCKER_IMAGE_TAG" 2>/dev/null || echo "")
  if [ "$API_METHOD" != "invoke" ]; then
      log "ERROR: The container image is missing the required label:"
      log "  LABEL org.grand-challenge.api-method=\"invoke\""
      log ""
      log "Without this label, Grand Challenge will not recognize that your"
      log "container implements the invoke API and will default to exec mode."
      log "Please add this label to your Dockerfile."
      exit 1
  fi
}

start_container() {
  log "Starting container"

  ## Note the extra arguments that are passed here:
  # '-p ${PORT}:4743'
  #    maps local port to container port 4743
  # '--gpus all'
  #    enables access to any GPUs present
  # '--volume <NAME>:/tmp'
  #   is added because on Grand Challenge this directory cannot be used to store permanent files
  # '--volume ../model:/opt/ml/model:ro'
  #   is added to provide access to the (optional) tarball-upload locally
  #
  # NOTE: --network none is NOT used here even though Grand Challenge runs
  # containers without network access. The invoke API requires the host to
  # reach the container's HTTP server via the mapped port, which is not
  # possible with --network none. In production, the sagemaker-shim calls
  # the invoke endpoint from inside the container so network isolation works.
  DOCKER_RUN_ARGS=(
      --detach
      --name "$CONTAINER_NAME"
      --platform=linux/amd64
      -p ${PORT}:4743 # Note 4743 is required
      --volume "$STAGING_INPUT_DIR":/input:ro
      --volume "$STAGING_OUTPUT_DIR":/output
      --volume "$DOCKER_NOOP_VOLUME":/tmp
      --volume "${SCRIPT_DIR}/model":/opt/ml/model:ro
  )

  docker run "${DOCKER_RUN_ARGS[@]}" "$DOCKER_IMAGE_TAG" >/dev/null

  log "Container started"
}

flush_docker_log() {
  docker logs --timestamps --since "$LOG_TIME" $CONTAINER_NAME
  LOG_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log $LOG_TIME
}


flush_docker_log() {
  local total_lines new_lines

  total_lines=$(docker logs "$CONTAINER_NAME" 2>&1 | wc -l)
  new_lines=$((total_lines - LOG_LINES_SHOWN))

  if (( new_lines > 0 )); then
    docker logs --timestamps --tail "$new_lines" "$CONTAINER_NAME"
  fi

  LOG_LINES_SHOWN=$total_lines
}



check_health() {
    log "Waiting for health endpoint..."

    local max_attempts=30
    local delay=3

    for ((i=1;i<=max_attempts;i++)); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            http://localhost:${PORT}/health || echo "000")

        log "Health check attempt $i/$max_attempts returned $STATUS"

        if [[ "$STATUS" == "200" ]]; then
            log "API healthy!"
            flush_docker_log
            return 0
        fi

        if [[ "$STATUS" == "302" ]]; then
            log "Health endpoint returned 302 — failing"
            flush_docker_log
            return 1
        fi

        log "Retrying in ${delay}s"
        sleep "$delay"
    done

    log "Health endpoint never returned 200"
    return 1
}

provision() {
    local interface_dir="$1"

    log "Provisioning input for ${interface_dir}"

    # Clear /output inside the container (host can't due to UID mismatch on Linux)
    docker exec --user root "$CONTAINER_NAME" \
        /bin/sh -c "rm -rf /output/*"

    # Clear the input staging dir, then hard-link the interface's input files in
    rm -rf "$STAGING_INPUT_DIR"/*
    cp -rl "${INPUT_DIR}/${interface_dir}/." "$STAGING_INPUT_DIR/"
}

invoke() {
    log "Calling invoke endpoint..."

    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 300 \
        -X POST http://localhost:${PORT}/invoke || echo "000")
    
    flush_docker_log

    if [ "$STATUS" != "201" ]; then
        log "Invoke failed with status $STATUS"
        exit 1
    fi

    log "...invoke completed"
}

collect_output() {
    local interface_dir="$1"

    log "Collecting output for ${interface_dir}"

    if [ -d "${OUTPUT_DIR}/$interface_dir" ]; then
      log "Cleaning up any earlier collected output"
      rm -rf "${OUTPUT_DIR}/$interface_dir"/*
    else
      mkdir -p -m o+rwX "${OUTPUT_DIR}/interf0"
    fi

    # Fix permissions so the host user can read the output files.
    # The container may have written them as a different UID on Linux.
    docker exec --user root "$CONTAINER_NAME" \
        /bin/sh -c "chmod -R -f o+rX /output/*"

    # Copy the output from the staging directory to the host output directory
    cp -rl "$STAGING_OUTPUT_DIR/." "${OUTPUT_DIR}/${interface_dir}/"
}

log() {
    local message="$1"
    if [[ -t 1 ]]; then
      printf "\e[38;2;36;150;237m> %s\e[0m\n" "$message"
    else
      # No user is watching, drop the colour
      printf "%s\n" "$message"
    fi
  }

main