[![CodeQL](https://github.com/ksquarekumar/whisper-stream/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/ksquarekumar/whisper-stream/actions/workflows/github-code-scanning/codeql)

# _Pre-Configured Docker Image for Jupyter_

> Derives from NVIDIA's `pytorch-ubuntu` NGC Image

## Build

```shell
docker buildx build -t jupyter-docker:latest -f Dockerfile --build-arg USER_NAME=${USER_NAME} --build-arg USER_NAME=${USER_NAME} --build-arg EMAIL_ADDRESS=${EMAIL_ADDRESS} > .
```

## RUN

```shell
docker run -itd jupyter-docker:latest --env $PORT
```

## Updating 💀

![☠️](https://imgs.xkcd.com/comics/python_environment_2x.png)

```shell
poetry add dep_name --lock
poetry2conda pyproject.toml environment_jupyter.yaml --dev
```

```shell
mamba env update -f environment_jupyter.yaml --dry-run
```

Move packages not found / un-resolvable to pip like so

```yaml
dependencies:
  - pip:
      - not_found
```
