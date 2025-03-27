# Alertmanager Tests

This directory contains the default alertmaanger template and a test prometheus alert payload used to test the alertmanager templates deployed with the platform.

_default.json is the _default template coming from the Prometheus Operator Chart.

_test.json is a Prometheus alert test payload.

_test-rule.yaml is a Prometheus alert rule.

### Usage

The makefile in the root of this module has a target to test the alertmanager templates.

```bash
make test-alertmanager-templates
```

To test an alert rule, you can use the following command:

```bash
kubectl apply -f tests/alertmanager/_test-rule.yaml
```
