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

target_env_name="python311"
conda_target_manifest_path="/opt/jupyter/kernels/${target_env_name}/environment.yml"
conda_target_requirements_path="/opt/jupyter/kernels/${target_env_name}/requirements.txt"
trt_setup_script_path="/opt/jupyter/scripts/setup_trt.sh"

# shellcheck source=/dev/null
source /etc/environment
# shellcheck source=/dev/null
source "${HOME}/.bashprofile"

export PIP_EXTRA_INDEX_URL="https://pypi.nvidia.com"
export OMP_NUM_THREADS=${OMP_NUM_THREADS}

# activate conda/mamba
echo "linking mamba"
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
# shellcheck source=/dev/null
if [ $? -eq 0 ]; then
  eval "$__conda_setup"
else
  if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    . "/opt/conda/etc/profile.d/conda.sh"
  else
    export PATH="/opt/conda/bin:$PATH"
  fi
fi
unset __conda_setup
# shellcheck source=/dev/null
if [ -f "/opt/conda/etc/profile.d/mamba.sh" ]; then
  . "/opt/conda/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# create env
phase="creating conda env: ${target_env_name}..."
echo "${phase}"
(mamba env create -f "${conda_target_manifest_path}" -v -y) || (echo "failed ${phase}" && exit 1)

# switch to active env
# shellcheck source=/dev/null
mamba activate ${target_env_name}

# continiue installing packages
phase="installing packages into, and confguring ${target_env_name} environment..."
echo "${phase}"
("${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade -r "${conda_target_requirements_path}" -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade eager natten -f https://shi-labs.com/natten/wheels/cu118/torch2.0.0/index.html -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade --upgrade-strategy eager "optimum[onnxruntime,onnxruntime-gpu,exporters,exporters-gpu,exporters-tf,dev,benchmark]"@git+https://github.com/huggingface/optimum.git -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade --upgrade-strategy eager "optimum-neuron[neuron,neuronx]"@git+https://github.com/huggingface/optimum-neuron.git -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade --upgrade-strategy eager "optimum-intel[extras]"@git+https://github.com/huggingface/optimum-intel.git -v \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" install --no-cache-dir --upgrade "nvidia-pytriton"@git+https://github.com/triton-inference-server/pytriton.git -v) || (echo "failed ${phase}" && exit 1)

# setup trt
phase="installing tensor-rt..."
echo "${phase}"
("${trt_setup_script_path}" --install) || (echo "failed ${phase}" && exit 1)

# install kernel
phase="installing kernel ..."
echo "${phase}"
("${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/python" -m ipykernel install --sys-prefix --name "${target_env_name}-mamba") || (echo "failed ${phase}" && exit 1)

# cleanup
phase="cleaning up cache..."
echo "${phase}"
("${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" remove "*" || true \
  && "${CONDA_PREFIX_BASE}/envs/${target_env_name}/bin/pip" cache purge || true) || (echo "failed ${phase}" && exit 1)
