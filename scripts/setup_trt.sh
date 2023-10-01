#!/bin/bash
##
## # Copyright © 2023 krishnakumar <ksquarekumar@gmail.com>.
## #
## # Licensed under the Apache License, Version 2.0 (the "License"). You
## # may not use this file except in compliance with the License. A copy of
## # the License is located at:
## #
## # https://github.com/ksquarekumar/jupyter-docker/blob/main/LICENSE
## #
## # or in the "license" file accompanying this file. This file is
## # distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
## # ANY KIND, either express or implied. See the License for the specific
## # language governing permissions and limitations under the License.
## #
## # This file is part of the jupyter-docker project.
## # see (https://github.com/ksquarekumar/jupyter-docker)
## #
## # SPDX-License-Identifier: Apache-2.0
## #
## # You should have received a copy of the APACHE LICENSE, VERSION 2.0
## # along with this program. If not, see <https://apache.org/licenses/LICENSE-2.0>
##
set -ex

# shellcheck source=/dev/null
source /etc/environment
# shellcheck source=/dev/null
source "${HOME}/.bashprofile"

scriptname=$0
trt_source="/opt/tensorrt/python/python_setup.sh"

trt_from_source="/workspace"
trt_to_source="/opt/trt-workspace"

function print_usage {
  echo "usage: $scriptname [--install] [--migrate] [--help]"
  echo "  --install install tensor-rt"
  echo "  --migrate migrate tensor-rt workspace from ${trt_from_source} to ${trt_to_source}"
  echo "  --help print this usage"
  exit 1
}

# activate mamba env
function check_and_activate {
  if command -v mamba > /dev/null; then
    echo "mamba found, proceeding..."
    mamba activate "${MAMBA_TARGET_ENV_NAME}"
    if [[ "$(which python)" != "/opt/conda/bin/envs/${MAMBA_TARGET_ENV_NAME}" ]]; then
      echo "incorrect python for ${MAMBA_TARGET_ENV_NAME}"
      printf "expected %s, got %s" "/opt/conda/bin/envs/${MAMBA_TARGET_ENV_NAME}" "$(which python)"
      exit 1
    fi
  else
    echo "mamba not found, exiting(!)" && exit 1
  fi
}

# install trt-deps in active environment
function install_trt {
  check_and_activate && (mamba run --no-capture-output -n "${MAMBA_TARGET_ENV_NAME}" "${trt_source}" || echo "failed to setup trt for env" && exit 1)
}

# move workspace to /opt/trt-workspace
function migrate_trt_workspace {
  echo "moving ${trt_from_source} to ${trt_to_source}"

  if [[ -e ${trt_from_source} ]]; then
    (echo "${trt_from_source} exists..." \
      && echo "moving ${trt_from_source} to ${trt_to_source}" \
      && mv /workspace /opt/trt-workspace \
      && chmod -R 777 /opt/trt-workspace) || (echo "failed to migrate tensor-rt workspace" && exit 1)
  fi
}

for arg in "$@"; do
  case $arg in
    --install*)
      install_trt
      shift
      ;;
    --migrate*)
      migrate_trt_workspace
      shift
      ;;
    --help*)
      print_usage
      exit 1
      ;;
    *)
      printf "Unrecognized Option %s\n" "${arg}"
      print_usage
      exit 1
      ;;
  esac
done
