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
MAXIMUM_MIRRORS=${MAXIMUM_MIRRORS:-4}

# Update the sources.list file with the fastest mirrors
sources_file="/etc/apt/sources.list"

# Set the release name variable
if command -v lsb_release > /dev/null; then
  echo "lsb_release found, using the distrbution release"
else
  echo "lsb_release not found, installing lsb_release"
  apt-get update \
    && apt-get install -y \
      --no-install-suggests \
      --no-install-recommends \
      lsb-release \
      apt-transport-https \
      software-properties-common
fi

# shellcheck disable=SC2005
release="$(echo "$(lsb_release --codename)" | awk '{print $2}')"

# install apt-smart package
if command -v pip > /dev/null; then
  echo "pip not found, installing python3-pip"
  apt-get update -o Acquire::CompressionTypes::Order::=gz && apt-get -y install python3-full python3-pip
fi

pip install --no-cache-dir --upgrade apt-smart

# Fetch the list of Ubuntu mirrors and measure download speeds
# shellcheck disable=SC2016
mirrors="$(apt-smart -l -x "*coganng*" -x "*ports*" -x "*heanet*")"
mirror_speeds=$(echo "${mirrors}" | tr '\n' ', ' | cut -d ',' -f "1-${MAXIMUM_MIRRORS}")
echo "Using: ${mirrors}"

if [[ -f "$sources_file" ]]; then
  cp "$sources_file" "$sources_file.bak"
  echo '' > "$sources_file"
  # Set the IFS to a comma to split the string into an array
  IFS=',' read -ra mirror_speeds_array <<< "$mirror_speeds"
  for mirror in "${mirror_speeds_array[@]}"; do
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
  done
else
  echo "Error: $sources_file not found."
fi

# Refresh the package cache and install apt-fast
add-apt-repository ppa:apt-fast/stable -y \
  && apt-get update -o Acquire::CompressionTypes::Order::=gz \
  && apt-get -y install apt-fast \
  && echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections \
  && echo debconf apt-fast/dlflag boolean true | debconf-set-selections \
  && echo debconf apt-fast/aptmanager string apt | debconf-set-selections \
  && echo debconf apt-fast/downloadbefore boolean false | debconf-set-selections

# Update the apt-fast.conf file with the fastest mirrors
conf_file="/etc/apt-fast.conf"
echo "updating apt-fast mirrors to: MIRRORS=( '${mirror_speeds}' )" >> "$conf_file"
echo "MIRRORS=( '${mirror_speeds}' )" >> "$conf_file"
