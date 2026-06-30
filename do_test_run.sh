#!/usr/bin/env bash
#
# do_test_run.sh
#
# Builds the algorithm's Docker image, boots it as an HTTP server that
# implements Grand Challenge's "invoke" API, then exercises it against two
# local test interfaces (interf0, interf1). For each interface this script:
#   1. stages the interface's input files into the container's /input mount
#   2. calls POST /invoke and checks for a 201 response
#   3. copies whatever the container wrote to /output back to the host
#
# Run this after changing the algorithm to confirm the container still
# behaves correctly before uploading it (see ./do_save.sh).

# Exit immediately on: an error in any command, use of an unset variable,
# or a failure in any stage of a pipeline (not just the last stage).
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DOCKER_IMAGE_TAG="example_algorithm_phase-1"
CONTAINER_NAME="example_algorithm_phase-1_container"

INPUT_DIR="${SCRIPT_DIR}/test/input"
OUTPUT_DIR="${SCRIPT_DIR}/test/output"

# Staging directories are bind-mounted into the container as /input and
# /output. They start empty and are (re)provisioned with hard-linked input
# files right before each invocation.
STAGING_INPUT_DIR="${SCRIPT_DIR}/test/.staging_input"
STAGING_OUTPUT_DIR="${SCRIPT_DIR}/test/.staging_output"

# How long to wait for the container's /health endpoint to come up.
HEALTH_CHECK_MAX_ATTEMPTS=30
HEALTH_CHECK_DELAY_SECONDS=3       # ~90s total before giving up
HEALTH_CHECK_TIMEOUT_SECONDS=10

# How long a single /invoke call is allowed to run.
INVOKE_TIMEOUT_SECONDS=300

# --- Globals -------------------------------------------------------------
LOG_LINES_SHOWN=0
DOCKER_VOLUME_TAG=""    # set by setup()
DOCKER_NETWORK_TAG=""   # set by setup()
# ---------------------------------------------------------------------------


main() {
  setup
  trap cleanup EXIT   # guarantee cleanup runs even if a later step fails

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
  log "Setup ..."
  # Allow the Docker user to read these on the host
  chmod -R -f o+rX "$INPUT_DIR" "${SCRIPT_DIR}/model"

  # Disable promotional logs from Docker
  export DOCKER_CLI_HINTS=false

  # Create empty staging directories for the /input and /output bind mounts
  rm -rf "$STAGING_INPUT_DIR" "$STAGING_OUTPUT_DIR"
  mkdir -m o+rwX "$STAGING_INPUT_DIR"
  mkdir -m o+rwX "$STAGING_OUTPUT_DIR"

  # A scratch volume that mimics the high I/O scratch on Grand Challenge
  DOCKER_VOLUME_TAG="${DOCKER_IMAGE_TAG}-scratch"
  docker volume create "$DOCKER_VOLUME_TAG" > /dev/null

  # The container's required listening port, and the URL the tester sidecar
  # uses to reach it (resolved by container name via Docker's embedded DNS).
  CONTAINER_PORT=4743
  BASE_URL="http://${CONTAINER_NAME}:${CONTAINER_PORT}"

  # The tester sidecar's image. Pin this to a specific tag in your own repo
  # for reproducibility; `latest` is used here for simplicity.
 


  # An isolated network that mimics restrictions on Grand Challenge.
  # NOTE: --internal networks cannot be used with -p/--publish, and the
  # algorithm container's IP on it usually isn't reachable from the real
  # host (see header comment) -- that's why the tester sidecar exists.
  DOCKER_NETWORK_TAG="${DOCKER_IMAGE_TAG}-isolated"
  docker network create --internal "$DOCKER_NETWORK_TAG" > /dev/null

  # The tester sidecar: lives on the isolated network so it can reach the
  # algorithm container by name, and is how we issue health/invoke checks
  # without needing the real host to route into that network.
  TESTER_NAME="${DOCKER_IMAGE_TAG}-tester"
  docker run --detach --name "$TESTER_NAME" \
      --network "$DOCKER_NETWORK_TAG" \
      curlimages/curl:latest sleep infinity > /dev/null
}


cleanup() {
  log "Cleanup ..."

  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm -f "$TESTER_NAME" >/dev/null 2>&1 || true
  log "Container stopped"

  # Remove staging directories
  rm -rf "$STAGING_INPUT_DIR" "$STAGING_OUTPUT_DIR"

  # Remove the volume and network
  docker volume rm "$DOCKER_VOLUME_TAG" > /dev/null 2>&1 || true
  docker network rm "$DOCKER_NETWORK_TAG" > /dev/null 2>&1 || true
}


build_container() {
  log "(Re)build the container"
  source "${SCRIPT_DIR}/do_build.sh"

  log "Verifying container labels"
  local api_method
  api_method=$(docker inspect \
      --format='{{index .Config.Labels "org.grand-challenge.api-method"}}' \
      "$DOCKER_IMAGE_TAG" 2>/dev/null || echo "")

  if [ "$api_method" != "invoke" ]; then
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

  # Extra arguments worth calling out:
  #   --network <isolated>   no internet access (see header comment); no -p
  #                          here since publishing doesn't work on internal
  #                          networks -- see the tester sidecar instead
  #   --volume <vol>:/tmp    scratch space (Grand Challenge disallows writes
  #                          elsewhere outside the mounted directories)
  #   --volume model:/opt/ml/model:ro   the (optional) tarball-upload, locally
  local docker_run_args=(
    --detach
    --name "$CONTAINER_NAME"
    --platform=linux/amd64
    --volume "${SCRIPT_DIR}/model":/opt/ml/model:ro
    --volume "$STAGING_INPUT_DIR":/input:ro
    --volume "$STAGING_OUTPUT_DIR":/output
    --volume "$DOCKER_VOLUME_TAG":/tmp
    --network "$DOCKER_NETWORK_TAG"
  )

  docker run "${docker_run_args[@]}" "$DOCKER_IMAGE_TAG" >/dev/null

  log "Container started; reachable from the tester sidecar at ${BASE_URL}"
}


flush_docker_log() {
  # Prints any container log lines that haven't been shown yet, then updates
  # LOG_LINES_SHOWN so the next call only prints what's new.

  local total_lines new_lines

  total_lines=$(docker logs "$CONTAINER_NAME" 2>&1 | wc -l)
  new_lines=$((total_lines - LOG_LINES_SHOWN))

  if (( new_lines > 0 )); then
    docker logs --timestamps --tail "$new_lines" "$CONTAINER_NAME"
  fi

  LOG_LINES_SHOWN=$total_lines
}


http_status() {
  # Issues a request *from inside the tester sidecar* (not the host -- see
  # header comment) and prints just the HTTP status code, or "000" if the
  # request couldn't be completed at all (e.g. connection refused). This is
  # the single call site for `docker exec ... curl` so all requests to the
  # algorithm container go through one place.

  local method="$1"
  local timeout_seconds="$2"
  local url="$3"

  docker exec "$TESTER_NAME" \
      curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout_seconds" \
      -X "$method" "$url" \
    || echo "000"
}


check_health() {
  log "Waiting for health endpoint..."

  local status
  for ((i = 1; i <= HEALTH_CHECK_MAX_ATTEMPTS; i++)); do
    status=$(http_status "GET" "$HEALTH_CHECK_TIMEOUT_SECONDS" "${BASE_URL}/health")

    log "Health check attempt $i/${HEALTH_CHECK_MAX_ATTEMPTS} returned $status"

    if [[ "$status" == "200" ]]; then
      log "API healthy!"
      flush_docker_log
      return 0
    fi

    if [[ "$status" == "302" ]]; then
      log "Health endpoint returned 302 — failing"
      flush_docker_log
      return 1
    fi

    log "Retrying in ${HEALTH_CHECK_DELAY_SECONDS}s"
    sleep "$HEALTH_CHECK_DELAY_SECONDS"
  done

  log "Health endpoint never returned 200"
  return 1
}


provision() {
  local interface_dir="$1"

  log "Provisioning input for ${interface_dir}"

  # Clear /output inside the container (host can't, due to UID mismatch on Linux)
  docker exec --user root "$CONTAINER_NAME" /bin/sh -c "rm -rf /output/*"

  # Clear the input staging dir, then hard-link this interface's input files in
  rm -rf "${STAGING_INPUT_DIR:?}"/*
  cp -rl "${INPUT_DIR}/${interface_dir}/." "$STAGING_INPUT_DIR/"
}


invoke() {
  log "Calling invoke endpoint..."

  local status
  status=$(http_status "POST" "$INVOKE_TIMEOUT_SECONDS" "${BASE_URL}/invoke")

  flush_docker_log

  if [ "$status" != "201" ]; then
    log "Invoke failed with status $status"
    exit 1
  fi

  log "...invoke completed"
}


collect_output() {
  local interface_dir="$1"
  local destination="${OUTPUT_DIR}/${interface_dir}"

  log "Collecting output for ${interface_dir}"

  if [ -d "$destination" ]; then
    log "Cleaning up any earlier collected output"
    rm -rf "${destination:?}"/*
  else
    mkdir -p -m o+rwX "$destination"
  fi

  # Fix permissions so the host user can read the output files.
  # The container may have written them as a different UID on Linux.
  docker exec --user root "$CONTAINER_NAME" \
      /bin/sh -c "chmod -R -f o+rX /output/*"

  # Copy from the staging directory to the host output directory
  cp -rl "$STAGING_OUTPUT_DIR/." "${destination}/"
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