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
ARG SOURCE_IMAGE_NAME="tensorrt"
ARG SOURCE_IMAGE_RELEASE="23.08-py3"

# PULL FROM BASE SOURCE
FROM "nvcr.io/nvidia/${SOURCE_IMAGE_NAME}:${SOURCE_IMAGE_RELEASE}" AS source
RUN date -u +"%Y-%m-%dT%H:%M:%SZ" > /build_date

# START BASE STAGE
FROM source as base

COPY --from=source /build_date /build_date
COPY scripts/update_mirrors.sh /opt/update_mirrors.sh

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
ARG ZSH_DOCKER_RELEASE="1.1.5"
ARG XLA_PYTHON_CLIENT_PREALLOCATE="false"
ARG XLA_PYTHON_CLIENT_MEM_FRACTION=".50"

# SET BASE ENV FLAGS & OPTIONS
ENV PORT="${PORT}" \
    LC_ALL="C.UTF-8" \
    PATH="~/.local/bin:/usr/local/bin:${PATH}" \
    DEBIAN_FRONTEND="noninteractive" \
    PYTHONUNBUFFERED=1 \
    USER_NAME="${USER_NAME}" \
    EMAIL_ADDRESS="${EMAIL_ADDRESS}" \
    SOURCE_IMAGE_NAME="${SOURCE_IMAGE_NAME}" \
    SOURCE_IMAGE_RELEASE="${SOURCE_IMAGE_RELEASE}" \
    MAXIMUM_MIRRORS="${MAXIMUM_MIRRORS}" \
    NODE_OPTIONS="${NODE_OPTIONS}" \
    NODE_MAJOR="${NODE_MAJOR}" \
    JAVA_VERSION="${JAVA_VERSION}" \
    ZSH_DOCKER_RELEASE="${ZSH_DOCKER_RELEASE}" \
    CONDA_CONFIG_CHANNEL_PRIORITY="${CONDA_CONFIG_CHANNEL_PRIORITY}" \
    CONDA_PREFIX_BASE="${CONDA_PREFIX_BASE}" \
    POETRY_CONFIG_DIR="~/.config/pypoetry" \
    POETRY_DATA_DIR="~/.local/share/pypoetry" \
    POETRY_CACHE_DIR="~/.cache/pypoetry" \
    PIP_CONFIG_FILE="~/.config/pip" \
    PIP_EXTRA_INDEX_URL='https://pypi.nvidia.com' \
    PIP_DEFAULT_TIMEOUT=60 \
    XLA_PYTHON_CLIENT_MEM_FRACTION="${XLA_PYTHON_CLIENT_MEM_FRACTION}" \
    XLA_PYTHON_CLIENT_PREALLOCATE="${XLA_PYTHON_CLIENT_PREALLOCATE}"

# CHANGE DEFAULT SHELL (-ex)
SHELL ["/bin/bash", "--login", "-ex", "-c"]

# INSTALL CORE PACKAGES AND SETUP FOR ENV
# REGISTER nodejs & yarn repos
# REGISTER docker repo
# REGISTER nvidia-docker repo
# REGISTER ngrok
# UPDATE SOURCES
# INSTALL nodejs & yarn
# INSTALL Docker & Co.
# INSTALL nvidia-docker
# INSTALL ngrok
# SETUP git
# ref: https://nextjournal.com/schmudde/jupyterdash-and-ngrok
# hadolint ignore=DL3008,DL3009,DL3013,DL3015,SC1091,DL4006
RUN /opt/update_mirrors.sh \
    mkdir -p /etc/apt/keyrings \
    && mkdir -p /opt/code \
    && mkdir -p /var/lock/apache2 \
    /var/run/apache2 \
    /var/run/sshd \
    /var/log/supervisor \
    && chmod -R 0777 /opt/code \
    && install -m 0755 -d /etc/apt/keyrings \
    && apt-fast upgrade -y -q \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    wget \
    sudo \
    python3-openssl \
    tzdata \
    fontconfig \
    locales \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [trusted=yes signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarnpkg.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/yarnpkg.gpg] https://dl.yarnpkg.com/debian/ rc main" | tee /etc/apt/sources.list.d/yarn.list \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
    && curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list \
    && apt-fast update -o Acquire::CompressionTypes::Order::=gz \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    apache2 \
    supervisor \
    ssh \
    ssh-askpass \
    ssh-tools \
    sshfs \
    openssh-server \
    openssh-client \
    openssh-client-ssh1 \
    checkinstall \
    python3-pkgconfig \
    cmake \
    clang-15 \
    llvm-15 \
    llvm-15-linker-tools \
    llvm-15-runtime \
    zip \
    unzip \
    lzma \
    cron \
    htop \
    aria2 \
    tmux \
    zsh \
    axel \
    procps \
    pkg-config \
    "${JAVA_VERSION}-jre" \
    pax-utils \
    libxml2 \
    libavformat-extra \
    libavcodec-extra \
    libavdevice58 \
    libavutil56 \
    libavfilter-extra \
    libswscale5 \
    libswresample3 \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    libswresample-dev \
    multimedia-devel \
    expat \
    libuv1 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libfreetype6 \
    fonts-powerline \
    python3-powerline \
    libxi6 \
    graphviz \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    nodejs \
    yarn \
    && apt-get remove -y yarn cmdtest \
    && apt-fast update -o Acquire::CompressionTypes::Order::=gz \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    nodejs \
    yarn \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true \
    && apt-fast install -y \
    --no-install-suggests \
    --no-install-recommends \
    nvidia-container-toolkit \
    && nvidia-ctk runtime configure --runtime=docker || true \
    && nvidia-ctk runtime configure --runtime=containerd || true \
    && apt-fast install -y ngrok \
    --no-install-suggests \
    --no-install-recommends \
    && git config --global credential.helper store \
    && git config --global core.filemode false

# MAKE ZSH BOOTSTRAP AVAILABLE
# INSTALL AWS CLI v2
# INSTALL configurable-http-proxy
# INSTALL CODE SERVER
# hadolint ignore=DL4006
WORKDIR /tmp

# hadolint ignore=DL4001,DL4006
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_DOCKER_RELEASE}/zsh-in-docker.sh --progress=dot:giga)" \
    -p git \
    -p python \
    -p virtualenv \
    -p ssh-agent \
    -p docker \
    -p docker-compose \
    -p fzf \
    -p aws \
    -p 'history-substring-search' \
    -p https://github.com/Pilaton/OhMyZsh-full-autoupdate \
    -p https://github.com/fourdim/zsh-poetry \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-completions \
    -p https://github.com/zdharma-continuum/fast-syntax-highlighting \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip \
    && /usr/bin/npm install --location=global --save-dev \
    configurable-http-proxy \
    bash-language-server \
    dockerfile-language-server-nodejs \
    pyright \
    sql-language-server \
    unified-language-server \
    vscode-css-languageserver-bin \
    vscode-html-languageserver-bin \
    vscode-json-languageserver-bin \
    yaml-language-server \
    && curl -fsSL https://code-server.dev/install.sh | sh

# SWITCH TO DESIRED ACTIVE DIRECTORY
WORKDIR /opt/code

# COPY SOURCE(S)
COPY jupyter-codeserver-proxy "/opt/code/jupyter-codeserver-proxy"
COPY kernels "/opt/code/kernels"

# ADD CONDA PREFIX, BASE AND TARGET ENV TO PATH
ENV PATH="${CONDA_PREFIX_BASE}/envs/python311/bin:${CONDA_PREFIX_BASE}/envs/base/bin:${CONDA_PREFIX_BASE}/bin:${PATH}"

# SETUP MINIFORGE
# SET ROOT CONDA CONFIGS
# INSTALL PACKAGES FOR BASE ENV
# UPDATE BASE ENV and do POETRY INSTALL in BASE
# CREATE ACTIVE PYTHON ENV AND INSTALL PACKAGES
# hadolint ignore=DL3013,DL4001,SC2261
RUN curl -L -O "https://repo.anaconda.com/miniconda/Miniconda3-latest-$(uname)-$(uname -m).sh" \
    && bash "Miniconda3-latest-$(uname)-$(uname -m).sh" -b -u -p "${CONDA_PREFIX_BASE}" \
    && rm "Miniconda3-latest-$(uname)-$(uname -m).sh" \
    && conda init bash \
    && conda init zsh \
    && echo "source activate base" >> ~/.bashrc \
    && echo "source activate base" >> ~/.zshrc

# SWITCH SHELL TO CONDA BASE ENV SHELL (-ex)
SHELL ["conda", "run", "--no-capture-output", "-n", "base", "/bin/bash", "--login", "-ex", "-c"]

# hadolint ignore=DL3013,SC2239,SC2261
RUN conda config --prepend channels "nodefaults" \
    && conda config --prepend channels "conda-forge" \
    && conda config --prepend channels "intel" \
    && conda config --prepend channels "huggingface" \
    && conda config --prepend channels "nvidia" \
    && conda config --prepend channels "nvidia/label/cuda-11.8.0" \
    && conda config --set channel_priority "${CONDA_CONFIG_CHANNEL_PRIORITY}" \
    && conda config --set auto_stack "2" \
    && conda config --set auto_activate_base "true" \
    && conda config --set auto_update_conda "true" \
    && conda config --set pip_interop_enabled "true" \
    && conda install mamba conda-libmamba-solver -c conda-forge -y \
    && conda config --set solver libmamba \
    && mamba env update -f "/opt/code/kernels/base/environment.yml" \
    && mamba update --update-all -y \
    && jlpm add --dev  \
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
    && python3 -m visualpy install \
    && jupyter labextension install ipyaggrid \
    && jupyter lab build \
    && python3 -m pip install --no-cache-dir --upgrade nvidia-pyindex \
    && python3 -m poetry self add poetry-conda poetry-multiproject-plugin \
    && python3 -m poetry config virtualenvs.prefer-active-python true \
    && python3 -m poetry config virtualenvs.create true \
    && python3 -m poetry config virtualenvs.in-project true \
    && python3 -m poetry config virtualenvs.ignore-conda-env true \
    && python3 -m poetry config virtualenvs.options.always-copy false \
    && python3 -m poetry config virtualenvs.options.system-site-packages true \
    && python3 -m pip install --no-cache-dir --no-deps ./jupyter-codeserver-proxy/ \
    && mamba env create -f "/opt/code/kernels/python311/environment.yml" \
    && echo "source activate python311" >> ~/.bashrc \
    && echo "source activate python311" >> ~/.zshrc

# CHANGE SHELL TO TARGET ENV SHELL (-ex)
SHELL ["conda", "run", "--no-capture-output", "-n", "python311", "/bin/bash", "--login", "-ex", "-c"]

# CONTINUE INSTALLING PACKAGES
# INSTALL (env) IPyKernel
# DO CLEANUP!
# hadolint ignore=DL3013,SC2239,SC2261
RUN python3 -m pip install --no-cache-dir --upgrade nvidia-pyindex \
    && python3 -m pip install --no-cache-dir . \
    && python3 -m pip install --no-cache-dir --upgrade ipykernel xeus-python \
    && mamba update --update-all -y \
    && python3 -m ipykernel install --sys-prefix --name "python311-mamba" \
    && apt-get remove -y \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    libswresample-dev \
    multimedia-devel \
    && apt-get clean -yq \
    && apt-get autoclean  -yq \
    && apt-get autoremove --purge -yq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && conda clean -a -y

# WRAP UP
# COPY supervisor CONF
COPY supervisor/conf "/etc/supervisor/conf.d/supervisord.conf"

# CHANGE SHELL TO TARGET ENV SHELL
SHELL ["conda", "run", "--no-capture-output", "-n", "python311", "/bin/bash", "--login", "-c"]

# SET ENTRYPOINT
EXPOSE 22 $PORT
CMD ["conda", "run", "--no-capture-output", "-n", "python311", "/bin/bash", "--login", "-c", "/usr/bin/supervisord"]
