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

base_env_name="base"
conda_base_manifest_path="/opt/jupyter/kernels/${base_env_name}/environment.yml"
proxy_package_path="/opt/jupyter/jupyter-codeserver-proxy"

# shellcheck source=/dev/null
source /etc/environment
# shellcheck source=/dev/null
source "${HOME}/.bashprofile"

export PIP_EXTRA_INDEX_URL="https://pypi.nvidia.com"
export OMP_NUM_THREADS=${OMP_NUM_THREADS}

# install miniforge
phase="installing miniforge in ${CONDA_PREFIX_BASE}..."
echo "${phase}"
(curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh" \
  && bash "Mambaforge-$(uname)-$(uname -m).sh" -b -u -p "${CONDA_PREFIX_BASE}" \
  && rm "Mambaforge-$(uname)-$(uname -m).sh" \
  && "${CONDA_PREFIX_BASE}/bin/mamba" init bash \
  && "${CONDA_PREFIX_BASE}/bin/mamba" init zsh \
  && echo "source activate ${base_env_name}" >> "${HOME}/.bashrc" \
  && echo "source activate ${base_env_name}" >> "${HOME}/.zshrc") || (echo "failed ${phase}" && exit 1)

# activate conda/mamba
# shellcheck source=/dev/null
. "${CONDA_PREFIX_BASE}/etc/profile.d/conda.sh"

# install and confgure base environment
phase="installing packages into, and confguring ${base_env_name} environment..."
echo "${phase}"
(conda config --prepend aggressive_update_packages "pip" \
  && conda config --prepend aggressive_update_packages "ca-certificates" \
  && conda config --prepend aggressive_update_packages "certifi" \
  && conda config --prepend aggressive_update_packages "openssl" \
  && conda config --prepend channels "nodefaults" \
  && conda config --prepend channels "conda-forge" \
  && conda config --set channel_priority "${CONDA_CONFIG_CHANNEL_PRIORITY}" \
  && conda config --set auto_activate_base "true" \
  && conda config --set pip_interop_enabled "true" \
  && conda config --set default_threads "${OMP_NUM_THREADS}" \
  && mamba install zstandard -c conda-forge -y \
  && "${CONDA_PREFIX_BASE}/bin/pip" install --no-cache-dir --upgrade nvidia-pyindex \
  && mamba update --update-all -y \
  && mamba env update -f "${conda_base_manifest_path}" \
  && "${CONDA_PREFIX_BASE}/bin/poetry" self add poetry-conda poetry-multiproject-plugin --no-cache \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.prefer-active-python true \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.create true \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.in-project true \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.ignore-conda-env true \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.options.always-copy false \
  && "${CONDA_PREFIX_BASE}/bin/poetry" config virtualenvs.options.system-site-packages true) || (echo "failed ${phase}" && exit 1)

# install & configure jupyter-lab extensions in base environment
phase="installing & configuring jupyter-lab extensions in ${base_env_name} environment..."
echo "${phase}"
("${CONDA_PREFIX_BASE}/bin/jlpm" add --dev \
  bash-language-server \
  dockerfile-language-server-nodejs \
  pyright \
  sql-language-server \
  typescript-language-server \
  unified-language-server \
  vscode-css-languageserver-bin \
  vscode-html-languageserver-bin \
  vscode-json-languageserver-bin \
  yaml-language-server \
  && "${CONDA_PREFIX_BASE}/bin/visualpy" install \
  && "${CONDA_PREFIX_BASE}/bin/pip" install --no-cache-dir --no-deps "${proxy_package_path}" \
  && "${CONDA_PREFIX_BASE}/bin/python" -m ipykernel install --sys-prefix --name "python3-${base_env_name}") || (echo "failed ${phase}" && exit 1)

# cleanup
phase="cleaning up cache..."
echo "${phase}"
("${CONDA_PREFIX_BASE}/bin/pip" cache remove "*" || true \
  && "${CONDA_PREFIX_BASE}/bin/pip" cache purge || true \
  && "${CONDA_PREFIX_BASE}/bin/python" -m jupyterlab.labapp clean \
  && "${CONDA_PREFIX_BASE}/bin/poetry" cache clear PyPI --all || true \
  && "${CONDA_PREFIX_BASE}/bin/poetry" cache clear _default_cache --all || true \
  && conda clean -afy) || (echo "failed ${phase}" && exit 1)
