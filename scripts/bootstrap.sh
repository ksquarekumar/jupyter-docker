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

# shellcheck source=/dev/null
bash -c "/opt/scripts/tune_kernel_opts.py" && source /etc/environment

export CONDA_USER_ENVS_DIRECTORY="${HOME}/conda/envs"
export CONDA_USER_SHARED_PKGS_DIRECTORY="${HOME}/conda/packages"
export POETRY_CONFIG_DIR="${HOME}/.config/pypoetry"
export POETRY_DATA_DIR="${HOME}/.local/share/pypoetry"
export POETRY_CACHE_DIR="${HOME}/.cache/pypoetry"
export PIP_CONFIG_FILE="${HOME}/.config/pip"
export NGROK_CONFIG_PATH="${HOME}/.config/ngrok.yml"
export PATH="${HOME}/.local/bin${PATH:+:${PATH}}"

ln -sf /opt/scripts/ "${HOME}/scripts/"

if [[ ! -f "${NGROK_CONFIG_PATH}" ]]; then
  echo "${NGROK_CONFIG_PATH} does not exist, creating dummy ngrok config at ${NGROK_CONFIG_PATH}"
  touch "${NGROK_CONFIG_PATH}"
fi

chmod ugw+rx -R /opt/scripts "${HOME}/scripts/"
conda config --set default_threads "${OMP_NUM_THREADS}" \
  && conda config --set verify_threads "${OMP_NUM_THREADS}" \
  && conda config --set execute_threads "${OMP_NUM_THREADS}" \
  && conda config --set fetch_threads "${OMP_NUM_THREADS}" \
  && conda config --set repodata_threads "${OMP_NUM_THREADS}" \
  && conda config --prepend pkgs_dirs "${CONDA_USER_SHARED_PKGS_DIRECTORY}" \
  && conda config --prepend env_dirs "${CONDA_USER_ENVS_DIRECTORY}" \
  && dockerd-rootless-setuptool.sh install \
  && rm -rf "${HOME}/.docker/run" \
  && mkdir -p "${HOME}/.docker/run" \
  && docker context use rootless
