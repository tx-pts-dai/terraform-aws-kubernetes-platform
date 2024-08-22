# Documentation

This directory contains documentation for the [Terraform AWS Kubernetes Platform](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform).

## Local Development

To serve the contributing guide locally, [`mkdocs`](https://www.mkdocs.org/user-guide/installation/) and the [`mkdocs-material`](https://github.com/squidfunk/mkdocs-material#quick-start) extension must be installed. Both require Python and `pip`.

```console
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install \
  mkdocs \
  mkdocs-material \
  mkdocs-include-markdown-plugin
```

Once installed, the documentation can be served from the root directory:

```console
mkdocs serve
```
