# Alertmanager Templates

This directory contains templates for the Alertmanager configuration file.

_default.json is the _default template coming from the Proometheus Operator Chart. Is it not deployed with this module.

_test.json is a Prometheus alert test payload.

_test-rule.yaml is a Prometheus alert rule.

### Usage

The makefile in the root of this module has a target to test the alertmanager templates.

```bash
make test-alertmanager-templates
```
