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

# options
MAXIMUM_MIRRORS=${MAXIMUM_MIRRORS:-4}

# globals
sources_file="/etc/apt/sources.list"
conf_file="/etc/apt-fast.conf"
kernel_tuning_file="/opt/scripts/tune_kernel_opts.py"

phase="installing base packages for setup..."
echo "${phase}"
(apt-get update -o Acquire::CompressionTypes::Order::=gz -q > /dev/null \
  && apt-get install -y -q \
    --no-install-suggests \
    --no-install-recommends \
    python3-full \
    python-is-python3 \
    python3-pip \
    python3-openssl \
    python3-dev \
    python3-psutil \
    python3-joblib \
    python3-regex \
    python3-tqdm \
    python3-rich \
    glances \
    wget \
    sudo \
    procps \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    tzdata \
    fontconfig \
    locales) || (echo "failed ${phase}" && exit 1)

# Set the release name variable
if command -v lsb_release > /dev/null; then
  echo "lsb_release found, using distribution release..."
  # shellcheck disable=SC2005
  release="$(echo "$(lsb_release --codename)" | awk '{print $2}')"
else
  echo "lsb_release not found, exiting(!)" && exit 1
fi

# install apt-smart package
if command -v pip > /dev/null; then
  echo "system pip found, installing apt-smart and glances package(s)..."
  (pip install --no-cache-dir --upgrade -q apt-smart "glances[all]") || exit 1
else
  echo "pip not found, installing python3-pip, exiting(!)" && exit 1
fi

# Fetch the list of Ubuntu mirrors and measure download speeds
# shellcheck disable=SC2016
phase="searching for fastest package source mirror(s)..."
echo "${phase}"
mirrors="$(apt-smart -l -x "*coganng*" -x "*ports*" -x "*heanet*")"
fastest_mirrors=$(echo "${mirrors}" | tr '\n' ', ' | cut -d ',' -f "1-${MAXIMUM_MIRRORS}")
printf "fastest package source mirrors:\n%s" "${mirrors}"
printf "updating %s with fastest package source mirrors:\n%s" "${sources_file}" "${mirrors}"

if [[ -f "$sources_file" ]]; then
  (cp "$sources_file" "$sources_file.bak") || exit 1
  (echo '' > "$sources_file") || exit 1
  # Set the IFS to a comma to split the string into an array
  IFS=',' read -ra fastest_mirrors_array <<< "$fastest_mirrors"
  (for mirror in "${fastest_mirrors_array[@]}"; do
    {
      echo "deb $mirror $release main restricted"
      echo "deb $mirror $release universe"
      echo "deb $mirror $release multiverse"
      echo "deb $mirror $release-updates main restricted"
      echo "deb $mirror $release-updates universe"
      echo "deb $mirror $release-updates multiverse"
      echo "deb $mirror $release-backports main restricted universe multiverse"
      echo "deb $mirror $release-security main restricted"
      echo "deb $mirror $release-security universe"
      echo "deb $mirror $release-security multiverse"
    } >> "$sources_file"
  done) || (echo "failed ${phase}" && exit 1)
else
  echo "Error: $sources_file not found, exiting(!)" && exit 1
fi
printf "successfully updated %s with fastest package source mirrors" "${sources_file}"

# Refresh the package cache and install apt-fast
phase="installing & configuring apt-fast package manager..."
echo "${phase}"
(add-apt-repository ppa:apt-fast/stable -y \
  && apt-get update -o Acquire::CompressionTypes::Order::=gz -q > /dev/null \
  && apt-get install -y -q --no-install-suggests --no-install-recommends apt-fast \
  && echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections \
  && echo debconf apt-fast/dlflag boolean true | debconf-set-selections \
  && echo debconf apt-fast/aptmanager string apt | debconf-set-selections \
  && echo debconf apt-fast/downloadbefore boolean false | debconf-set-selections) || (echo "failed ${phase}" && exit 1)

# Update the apt-fast.conf file with the fastest mirrors
printf "updating apt-fast configuration at %s with fastest mirrors" "${conf_file}..."
printf "updating apt-fast mirrors to: %s in file: %s" "${fastest_mirrors}" "${conf_file}"
if [[ -f "$conf_file" ]]; then
  sed -i.bak s#MIRRORS=\(.*\)#"MIRRORS=( '${fastest_mirrors}' )" #g "${conf_file}" || ( echo "failed to edit ${conf_file}, exiting" && exit 1 )
else
  echo "Error: $conf_file not found, exiting(!)" && exit 1
fi

# do in-place system upgrade
printf "performing distribution-upgrade for %s %s kernel: %s version: %s codename: %s ..." "$(uname -o)" "$(uname -m)" "$(uname -r)" "$(uname -v)" "${release}"
apt-fast update -o Acquire::CompressionTypes::Order::=gz -q > /dev/null \
  && apt-fast upgrade -y -q

# prep for future installables
phase="creating directories for installable packages..."
echo "${phase}"
/bin/bash -c "${kernel_tuning_file}"
# shellcheck source=/dev/null
source /etc/environment
printf "+ OMP_NUM_THREADS: %s" "${OMP_NUM_THREADS}"
(mkdir -p /etc/apt/keyrings \
  && mkdir -p /opt/jupyter \
  && mkdir -p /var/lock/apache2 \
  && mkdir -p "${CONDA_PREFIX_BASE}\pkgs" \
    /var/run/apache2 \
    /var/run/sshd \
    /var/log/supervisor \
  && chmod -R 0777 /opt \
  && install -m 0755 -d /etc/apt/keyrings) || (echo "failed ${phase}" && exit 1)

# register addtional package sources
phase="registering addtional package sources..."
echo "${phase}"
# shellcheck source=/dev/null
(curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [trusted=yes signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
  && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarnpkg.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/yarnpkg.gpg] https://dl.yarnpkg.com/debian/ rc main" | tee /etc/apt/sources.list.d/yarn.list \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list \
  && apt-fast update -o Acquire::CompressionTypes::Order::=gz -q > /dev/null) || (echo "failed ${phase}" && exit 1)

# install requisite packages
phase="installing required packages..."
echo "${phase}"
(apt-fast install -y -q \
  --no-install-suggests \
  --no-install-recommends \
  apache2 \
  fuse3 \
  fuse2fs \
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
  pkg-config \
  ncdu \
  "${JAVA_VERSION}-jre" \
  pax-utils \
  libfuse3-3 \
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
  libfuse3-dev \
  libfuse-dev \
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
  graphviz) || (echo "failed ${phase}" && exit 1)

# install nodejs/npm/yarn
phase="installinging & configuring nodejs ecosystem..."
echo "${phase}"
(apt-fast install -y -q \
  --no-install-suggests \
  --no-install-recommends \
  nodejs \
  yarn \
  && apt-get remove -y -q yarn cmdtest \
  && apt-fast update -o Acquire::CompressionTypes::Order::=gz -q > /dev/null \
  && apt-fast install -y -q \
    --no-install-suggests \
    --no-install-recommends \
    nodejs \
    yarn \
  && npm config set cache "${NPM_CACHE_DIR}" --global \
  && yarn config set cache-folder "${YARN_CACHE_DIR}") || (echo "failed ${phase}" && exit 1)

# install docker & co.
phase="installing & configuring docker runtime..."
echo "${phase}"
(apt-fast install -y -q \
  --no-install-suggests \
  --no-install-recommends \
  uidmap \
  pigz \
  dbus-user-session \
  fuse-overlayfs \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras \
  && (systemctl disable --now docker.service docker.socket || true) \
  && (ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true)) || (echo "failed ${phase}" && exit 1)

# install nvidia-docker runtime
phase="installing nvidia-docker runtime..."
echo "${phase}"
(apt-fast install -y -q \
  --no-install-suggests \
  --no-install-recommends \
  nvidia-container-toolkit \
  && nvidia-ctk runtime configure --runtime=docker \
  && nvidia-ctk runtime configure --runtime=containerd) || (echo "failed ${phase}" && exit 1)

# install ngrok
phase="installing ngrok..."
echo "${phase}"
(apt-fast install -y -q --no-install-suggests --no-install-recommends ngrok) || (echo "failed ${phase}" && exit 1)

# configuring git
phase="configuring git..."
echo "${phase}"
(git config --global credential.helper store \
  && git config --global core.filemode false) || (echo "failed ${phase}" && exit 1)

# setting up shell
phase="setting up zsh..."
echo "${phase}"
(sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_DOCKER_RELEASE}/zsh-in-docker.sh --progress=dot:giga)" \
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
  -p https://github.com/zdharma-continuum/fast-syntax-highlighting) || (echo "failed ${phase}" && exit 1)

# installing awscli
phase="installing aws-cli-v2..."
echo "${phase}"
(cd /tmp \
  && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip -q awscliv2.zip \
  && ./aws/install \
  && rm -rf aws awscliv2.zip) || (echo "failed ${phase}" && exit 1)

# installing codeserver & congurable-http-proxy
phase="installing codeserver & congurable-http-proxy..."
echo "${phase}"
(/usr/bin/npm install --location=global --save-dev \
  configurable-http-proxy \
  && curl -fsSL https://code-server.dev/install.sh | sh) || (echo "failed ${phase}" && exit 1)
