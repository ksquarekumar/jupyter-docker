#!/usr/bin/python
#
# # Copyright © 2023 krishnakumar <ksquarekumar@gmail.com>.
# #
# # Licensed under the Apache License, Version 2.0 (the "License"). You
# # may not use this file except in compliance with the License. A copy of
# # the License is located at:
# #
# # https://github.com/ksquarekumar/jupyter-docker/blob/main/LICENSE
# #
# # or in the "license" file accompanying this file. This file is
# # distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# # ANY KIND, either express or implied. See the License for the specific
# # language governing permissions and limitations under the License.
# #
# # This file is part of the jupyter-docker project.
# # see (https://github.com/ksquarekumar/jupyter-docker)
# #
# # SPDX-License-Identifier: Apache-2.0
# #
# # You should have received a copy of the APACHE LICENSE, VERSION 2.0
# # along with this program. If not, see <https://apache.org/licenses/LICENSE-2.0>
#
"""
Bootstrap script for setting kernel opts and global system variables as needed.
"""
from pathlib import Path
from typing import Iterable
from joblib import cpu_count
import regex as re
from rich.console import Console


def set_omp_threads(env_file: Path, console: Console) -> None:
    """
    write OMP_NUM_THREADS to env after making a copy
    """
    # backup original
    if env_file.exists():
        console.log(f"backing up {env_file} to {env_file}.orig")
        temp_path: Path = Path(str(env_file.absolute()) + ".orig")
        data: str = env_file.read_text(encoding="utf-8")
        temp_path.touch(mode=int(oct(env_file.stat().st_mode)[-3:]))
        Path(temp_path).write_text(data, encoding="utf-8")
        console.log(f"successfully backed up {env_file} with data\n", data)
    else:
        console.log(f"creating {env_file} as it does not exist already")
        env_file.touch(755)

    # add/update omp_num_threads
    num_cpu: str = str(cpu_count())
    pattern = r"^(OMP_NUM_THREADS=)(\d{1,3})$"
    buffer: str = ""
    exists: bool = False
    with env_file.open("r+t", encoding="utf-8") as handle:
        for line in handle.readlines():
            match: re.Match[str] | None = re.match(pattern, line)
            if match is not None:
                buffer += f"{match.group(1)}{num_cpu}\n"
                exists = True
            else:
                buffer += line
    if exists is False and "OMP_NUM_THREADS" not in buffer:
        buffer += f"OMP_NUM_THREADS={num_cpu}"

    env_file.write_text(buffer, encoding="utf-8")
    console.log(
        f"successfully updated up {env_file} with data\n",
        env_file.read_text(encoding="utf-8"),
    )


def main(
    env_files: Iterable[Path],
) -> None:
    import tqdm

    console: Console = Console(
        color_system="auto", force_interactive=False, soft_wrap=True
    )

    for env_file in tqdm.tqdm(env_files):
        set_omp_threads(env_file=env_file, console=console)


if __name__ == "__main__":
    ENV_FILES: list[Path] = [
        Path("/etc/environment"),
        Path.home() / ".bashprofile",
        Path.home() / ".zprofile",
        Path.home() / ".bashrc",
        Path.home() / ".zshrc",
    ]
    main(env_files=ENV_FILES)
