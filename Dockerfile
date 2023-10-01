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

# GLOBAL ARGS
ARG SOURCE_IMAGE_NAME="tensorrt"
ARG SOURCE_IMAGE_RELEASE="23.08-py3"
ARG MAMBA_TARGET_ENV_NAME="python311"

# PULL FROM BASE SOURCE
FROM "nvcr.io/nvidia/${SOURCE_IMAGE_NAME}:${SOURCE_IMAGE_RELEASE}" AS source
RUN date -u +"%Y-%m-%dT%H:%M:%SZ" > /build_date

# START BUILD/BASE STAGE
FROM source as core

COPY --from=source --chmod=ugo+rw /build_date /build_date

LABEL maintainer="ksquarekumar@gmail.com"
LABEL license="Apache-2.0"
LABEL build-date="$(cat /build_date)"

ARG USER_NAME
ARG EMAIL_ADDRESS
ARG PORT="8000"
ARG SOURCE_IMAGE_NAME="tensorrt"
ARG SOURCE_IMAGE_RELEASE="23.08-py3"
ARG MAXIMUM_MIRRORS="4"
ARG CONDA_CONFIG_CHANNEL_PRIORITY="flexible"
ARG CONDA_PREFIX_BASE="/opt/conda"
ARG NODE_OPTIONS="--max-old-space-size=16000"
ARG JAVA_VERSION="openjdk-19"
ARG NODE_MAJOR="20"
ARG NGROK_PORT="8080"
ARG ZSH_DOCKER_RELEASE="1.1.5"
ARG XLA_PYTHON_CLIENT_PREALLOCATE="false"
ARG XLA_PYTHON_CLIENT_MEM_FRACTION=".50"
ARG MAMBA_TARGET_ENV_NAME="python311"

# SET BASE ENV FLAGS & OPTIONS
ENV PORT="${PORT}" \
    LC_ALL="C.UTF-8" \
    PATH="/usr/local/bin:${PATH}" \
    DEBIAN_FRONTEND="noninteractive" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    USER_NAME="${USER_NAME:-}" \
    EMAIL_ADDRESS="${EMAIL_ADDRESS:-}" \
    SOURCE_IMAGE_NAME="${SOURCE_IMAGE_NAME}" \
    SOURCE_IMAGE_RELEASE="${SOURCE_IMAGE_RELEASE}" \
    MAXIMUM_MIRRORS="${MAXIMUM_MIRRORS}" \
    NODE_OPTIONS="${NODE_OPTIONS}" \
    NODE_MAJOR="${NODE_MAJOR}" \
    JAVA_VERSION="${JAVA_VERSION}" \
    NGROK_PORT="${NGROK_PORT}" \
    ZSH_DOCKER_RELEASE="${ZSH_DOCKER_RELEASE}" \
    CONDA_CONFIG_CHANNEL_PRIORITY="${CONDA_CONFIG_CHANNEL_PRIORITY}" \
    CONDA_PREFIX_BASE="${CONDA_PREFIX_BASE}" \
    MAMBA_TARGET_ENV_NAME="${MAMBA_TARGET_ENV_NAME}" \
    POETRY_CONFIG_DIR="${HOME}/.config/pypoetry" \
    POETRY_DATA_DIR="${HOME}/.local/share/pypoetry" \
    POETRY_CACHE_DIR="${HOME}/.cache/pypoetry" \
    PIP_NO_CACHE_DIR="off"\
    PIP_CONFIG_FILE="${HOME}/.config/pip" \
    PIP_DEFAULT_TIMEOUT=60 \
    NPM_CACHE_DIR="${HOME}/.cache/npm-cache" \
    YARN_CACHE_DIR="${HOME}/.cache/yarn-cache" \
    DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock" \
    DOCKERD_ROOTLESS_ROOTLESSKIT_FLAGS="-p 0.0.0.0:2376:2376/tcp" \
    XLA_PYTHON_CLIENT_MEM_FRACTION="${XLA_PYTHON_CLIENT_MEM_FRACTION}" \
    XLA_PYTHON_CLIENT_PREALLOCATE="${XLA_PYTHON_CLIENT_PREALLOCATE}"

COPY --link --chmod=ugo+x scripts/setup_packages.sh /opt/scripts/setup_packages.sh
COPY --link --chmod=ugo+x scripts/tune_kernel_opts.py /opt/scripts/tune_kernel_opts.py

# CHANGE DEFAULT SHELL (-ex)
SHELL ["/bin/bash", "--login", "-ex", "-c"]

# SWITCH TO DESIRED ACTIVE DIRECTORY
WORKDIR /opt

# INSTALL CORE PACKAGES AND DO SETUP(s) FOR ENV
RUN /opt/scripts/setup_packages.sh

FROM core as base

COPY --link --chmod=ugo+x jupyter-codeserver-proxy "/opt/jupyter/jupyter-codeserver-proxy"
COPY --link --chmod=ugo+rw kernels/base/environment.yml "/opt/jupyter/kernels/base/environment.yml"
COPY --link --chmod=ugo+rw kernels/base/requirements.txt "/opt/jupyter/kernels/base/requirements.txt"
COPY --link --chmod=ugo+rx kernels/base/setup_base.sh "/opt/jupyter/kernels/base/setup_base.sh"

ENV PIP_EXTRA_INDEX_URL="https://pypi.nvidia.com"

# SETUP
RUN /opt/jupyter/kernels/base/setup_base.sh

FROM base as python311

COPY --link --chmod=ugo+x scripts/setup_trt.sh /opt/scripts/setup_trt.sh
COPY --link --chmod=ugo+rw kernels/${MAMBA_TARGET_ENV_NAME}/environment.yml "/opt/jupyter/kernels/${MAMBA_TARGET_ENV_NAME}/environment.yml"
COPY --link --chmod=ugo+rw kernels/${MAMBA_TARGET_ENV_NAME}/requirements.txt "/opt/jupyter/kernels/${MAMBA_TARGET_ENV_NAME}/requirements.txt"
COPY --link --chmod=ugo+rx kernels/${MAMBA_TARGET_ENV_NAME}/setup_${MAMBA_TARGET_ENV_NAME}.sh "/opt/jupyter/kernels/${MAMBA_TARGET_ENV_NAME}/setup_${MAMBA_TARGET_ENV_NAME}.sh"

ENV PATH="${CONDA_PREFIX_BASE}/bin:${PATH}"

# SETUP
RUN "/opt/jupyter/kernels/${MAMBA_TARGET_ENV_NAME}/setup_${MAMBA_TARGET_ENV_NAME}.sh"

# hadolint ignore=DL3006
FROM "${MAMBA_TARGET_ENV_NAME}" as final

# CHANGE DEFAULT SHELL (-ex)
SHELL ["mamba", "run", "--no-capture-output", "-n", "base", "/bin/bash", "--login", "-c"]

# MIGRATE TENSOR-RT workspace and CLEANUP!
# hadolint ignore=SC2035
RUN bash -c "${trt_setup_script_path}" --migrate \
    apt-get remove -y \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    libswresample-dev \
    multimedia-devel \
    libfuse3-dev \
    && apt-get clean -yq \
    && apt-get autoclean  -yq \
    && apt-get autoremove --purge -yq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && /usr/bin/python -m pip cache remove * \
    && /usr/bin/python -m pip cache purge \
    && rm -rf "${HOME}/.cache" \
    && rm -rf /root/.cache \
    && mamba clean -afy \
    && chmod -R 0777 /opt

# WRAP UP
# COPY supervisor CONF
COPY --link --chmod=ugo+rw glances/glances.conf "/opt/jupyter/glances.conf"
COPY --link --chmod=ugo+rx scripts/bootstrap.sh /opt/scripts/bootstrap.sh
COPY --link --chmod=ugo+rw supervisor/conf "/etc/supervisor/conf.d/supervisord.conf"

# SET ENTRYPOINT
EXPOSE 22 $PORT $NGROK_PORT
CMD ["mamba", "run", "--no-capture-output", "-n", "base", "/bin/bash", "--login", "-c", "/usr/bin/supervisord"]
