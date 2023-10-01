# TensorRT

The core of NVIDIA TensorRT is a C++ library that facilitates high performance
inference on NVIDIA graphics processing units (GPUs). TensorRT takes a trained
network, which consists of a network definition and a set of trained
parameters, and produces a highly optimized runtime engine which performs
inference for that network.

TensorRT provides API's via C++ and Python that help to express deep learning
models via the Network Definition API or load a pre-defined model via the
parsers that allows TensorRT to optimize and run them on a NVIDIA GPU.
TensorRT applies graph optimizations, layer fusion, among other optimizations,
while also finding the fastest implementation of that model leveraging a
diverse collection of highly optimized kernels. TensorRT also supplies a
runtime that you can use to execute this network on all of NVIDIA’s GPU’s from
the Kepler generation onwards.

TensorRT also includes optional high speed mixed precision capabilities
introduced in the Tegra X1, and extended with the Pascal, Volta, and Turing
architectures.

## Contents of the TensorRT image

This container has the TensorRT C++ library installed and ready to
use. The container also includes a python interface for TensorRT.

`/opt/tensorrt` contains the TensorRT C++ library, python interface,
samples and documentation.

`/workspace/tensorrt` contains copies of the TensorRT samples that can
be modified, compiled and executed.

## Running TensorRT Samples

You can build and run the TensorRT C++ samples from within the
image. For details on how to run each sample see the [TensorRT Developer
Guide](https://docs.nvidia.com/deeplearning/sdk/tensorrt-developer-guide/index.html).

```
$ cd /workspace/tensorrt/samples
$ make -j4
$ cd /workspace/tensorrt/bin
$ ./sample_onnx_mnist
```

You can also execute the TensorRT python samples.

```
$ cd /workspace/tensorrt/samples/python/introductory_parser_samples
$ python onnx_resnet50.py -d /workspace/tensorrt/data/
```

Some of the dependencies of the Python samples have not been pre-installed
in the container in order to save space. To install these dependencies, run
the following command before you run these samples.

```
$ /opt/tensorrt/python/python_setup.sh
```

## Customizing TensorRT

You can customize the TensorRT image in one of two ways:

(1) Add to or modify the source code in this container and run your
customized version or (2) use `docker build` to add your
customizations on top of this container if you want to add additional
packages.

NVIDIA recommends option 2 for ease of migration to later versions of the
TensorRT container image.

For more information, see https://docs.docker.com/engine/reference/builder for
a syntax reference.

## Suggested Reading

For the latest Release Notes, Developer and Installation Guides, see
the [TensorRT Documentation](http://docs.nvidia.com/deeplearning/dgx/tensorrt-release-notes/index.html) website.
