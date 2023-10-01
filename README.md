# _Pre-Configured Docker Image for Jupyter_

> Derives from NVIDIA's `pytorch-ubuntu` NGC Image

## Build

```shell
docker buildx build -t jupyter-docker:latest -f Dockerfile .
```

## RUN

```shell
docker run -itd jupyter-docker:latest --env "PORT=$PORT"
```

### [NGC Readme](./NGC_TENSORRT.md)

> `/workspace/tensorrt` is moved to `opt/trt-workspace`

## Development

```
poetry install .
```

### Updating 💀

![☠️](https://imgs.xkcd.com/comics/python_environment_2x.png)

#### 1. Add a new dependency to project and update lockfile

```shell
poetry add dep_name --lock
```

#### 2.1. Optional (Confirm package is available in `conda`)

```shell
poetry2conda pyproject.toml environment_jupyter.yaml --dev
```

```shell
mamba env update -f environment_jupyter.yaml --dry-run
```

Move packages not found / un-resolvable to pip like so

```yaml
# environment_jupyter.yml
dependencies:
  - pip:
      - not_found
```

or Just resort to `pip` installs through mamba

```yaml
# environment_jupyter.yml
dependencies:
  - pip:
      - -r requirements.txt
      - -e ./jupyter_codeserver_proxy
```
