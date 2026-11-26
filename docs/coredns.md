# CoreDNS

The module installs CoreDNS as the EKS-managed `coredns` add-on in every setup except pure Auto
Mode. On top of the add-on's defaults it sets the replica autoscaling, the container resources
(`addon_resources`) and its own Corefile, [`files/coredns/Corefile`](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/blob/main/files/coredns/Corefile).

## What the module's Corefile changes

The file is the add-on's default Corefile with one change in the `forward` block:

```diff
-    forward . /etc/resolv.conf
+    forward . /etc/resolv.conf {
+      prefer_udp
+    }
```

With [`prefer_udp`](https://coredns.io/plugins/forward/), CoreDNS sends queries to the upstream
resolver (the VPC resolver at the VPC CIDR base + 2, from `/etc/resolv.conf`) over UDP even when
the client asked over TCP. When an answer is too large for UDP, the resolver sets the truncated
(TC) flag and CoreDNS repeats the query over TCP. Clients still get their answer over the protocol
they used.

## Why

Without it, CoreDNS forwards a TCP query to the VPC resolver over TCP. On our clusters, a small
share of those TCP connections never opened, and CoreDNS answered SERVFAIL with:

```
[ERROR] plugin/errors: 2 example.com. A: dial tcp 10.x.0.2:53: i/o timeout
```

Three things combine:

1. **Tailscale exit nodes send every lookup over both protocols.** A client using an exit node
   sends its DNS to the exit node over DNS-over-HTTPS. The exit node handles these queries as TCP
   queries, and for TCP queries Tailscale's forwarder starts a UDP and a TCP query to its resolver
   (CoreDNS) at the same time, keeping the first answer
   ([`net/dns/resolver/forwarder.go`](https://github.com/tailscale/tailscale/blob/main/net/dns/resolver/forwarder.go)).
   On a cluster with an exit node, almost all TCP queries to CoreDNS come from there.
2. **CoreDNS's connect timeout to the upstream sits at its 1 s floor.** The timeout adapts to an
   average dial time that UDP and TCP share. UDP "dials" take microseconds, so TCP gets the
   1 s minimum (`minDialTimeout` in
   [`plugin/pkg/proxy`](https://github.com/coredns/coredns/tree/master/plugin/pkg/proxy)).
3. **Linux retransmits a lost SYN after 1 s.** A single dropped SYN to the VPC resolver is therefore
   enough to fail the connection. Why the SYNs are occasionally lost is not known. The per-ENI
   limit of 1024 packets per second to the VPC resolver is an unlikely cause: upstream volume
   was a few queries per second per pod, and UDP to the same resolver showed no losses.

Users rarely notice, because the UDP copy of the same lookup usually wins Tailscale's race. They
see a failure only when both copies fail, which is why the problem was hard to reproduce. The
errors are still real SERVFAILs, and they hide genuine DNS problems in the logs.

`prefer_udp` removes the TCP hop to the VPC resolver for everything except truncated answers.
It is also the setting several EKS write-ups recommend for CoreDNS in front of the VPC resolver.

### Evidence

Tested on disco-dev (FUM-4456) against disco-prod, which kept the default Corefile:

| | disco-dev, `prefer_udp` | disco-prod, default |
|---|---|---|
| TCP queries from clients | 22,535 | 20,654 |
| TCP connections to the VPC resolver | 29 | 17,958 |
| `dial tcp … i/o timeout` / `read tcp … i/o timeout` | none since the reload | 34 / 29 |

On dev the errors stopped at the moment CoreDNS reloaded the new Corefile.

## Configuration

Nothing to set: every cluster gets the module's Corefile. The `coredns` variable covers the
other cases.

Use the add-on's built-in Corefile instead:

```hcl
coredns = {
  use_addon_default_corefile = true
}
```

Install your own Corefile (it replaces the whole file, so start from
[`files/coredns/Corefile`](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/blob/main/files/coredns/Corefile)):

```hcl
coredns = {
  corefile = file("${path.module}/files/Corefile")
}
```

An `extra_cluster_addons` entry named `coredns` replaces the module's whole add-on definition,
Corefile included, and the `coredns` variable no longer applies.

### Applying it

Upgrading to a module version that sets the Corefile is one in-place update of the `coredns`
add-on's `configuration_values`. EKS rewrites the `coredns` ConfigMap, CoreDNS's `reload` plugin
picks it up within about 30 seconds, and the Deployment may also roll.

### Going back to the add-on's default

Set `coredns = { use_addon_default_corefile = true }` and apply. This removes `corefile` from the
add-on's `configuration_values`, and EKS is expected to write its built-in Corefile back to the
ConfigMap. **This path has not been tested yet.** After the apply, check the ConfigMap:

```sh
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -A2 forward
```

If `prefer_udp` is still there, EKS kept the previous Corefile. Install the default explicitly
instead: pass `files/coredns/Corefile` without the `prefer_udp` lines as `coredns.corefile`, which
gives `forward . /etc/resolv.conf` on its own line. Once the rollback has been tested, replace
this note with the result.

## Keeping the Corefile in step with the add-on

A `corefile` value replaces the add-on's default Corefile completely, and the add-on still
tracks the newest version for the cluster's Kubernetes version (`most_recent = true`). Two
consequences:

- **Changes AWS makes to the default Corefile never reach clusters.** New plugins, changed cache
  or health settings and fixes stay out until `files/coredns/Corefile` is updated.
- **EKS does not validate the Corefile.** If a newer CoreDNS drops a plugin or option the file
  uses, the add-on update is accepted and new CoreDNS pods crash-loop. CoreDNS has done this
  before: `proxy` was removed in favour of `forward`, and options such as `upstream` were
  removed from the `kubernetes` block.

AWS does not publish the default Corefile in the add-on's configuration schema, so it has to be
read from a cluster running the add-on with its default.

### When to check

- Before every release that bumps the default `kubernetes_version`. That is when the newest
  compatible add-on moves to a new CoreDNS minor version, so default and plugin changes are most
  likely. The `eks-k8s-version-upgrade` skill includes this step.
- When AWS publishes a CoreDNS add-on build with a new CoreDNS minor for the current Kubernetes
  version.

### How to check

1. Find the add-on version clusters will get:

   ```sh
   aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.N \
     --query 'addons[0].addonVersions[0].addonVersion' --output text
   ```

2. Read the default Corefile of that version from a cluster created with the add-on's default,
   for example a new `tests/main` feature cluster with
   `coredns = { use_addon_default_corefile = true }`. On an existing cluster that had the
   module's Corefile, check first that the switch actually restored the default (see
   "Going back to the add-on's default"):

   ```sh
   kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile.default
   ```

3. Compare it with the module's file. Only the `prefer_udp` lines in `forward` should differ:

   ```sh
   diff /tmp/Corefile.default files/coredns/Corefile
   ```

4. Read the [CoreDNS release notes](https://github.com/coredns/coredns/releases) between the
   current and the new CoreDNS version for removed or renamed plugins and options used in the
   file.
5. If the default changed, copy it into `files/coredns/Corefile`, add `prefer_udp` back to
   `forward`, and ship it with the version bump.

### If CoreDNS fails after an add-on update

New CoreDNS pods in `CrashLoopBackOff` with a Corefile parse error in their logs, and the add-on
in `DEGRADED`, point to a Corefile the new version rejects. To restore DNS quickly, install a
Corefile the new version accepts on the affected cluster: either
`coredns = { use_addon_default_corefile = true }`, checking the ConfigMap as described in
"Going back to the add-on's default", or a fixed copy through `coredns = { corefile = ... }`,
which always replaces the ConfigMap. Then fix `files/coredns/Corefile` as above.
