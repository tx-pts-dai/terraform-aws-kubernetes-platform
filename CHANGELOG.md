
v2.0.0+1.32.0

Breaking Changes:

- Setting disk size via the karpenter variable is now deprecated. Use the karpenter_resources variable instead.

```
karpenter = {
  ...
  data_volume_size = 80Gi
  ...
}
```

Use the karpenter_resources variable instead.

```
karpenter = {
  ...
  karpenter_resources = {
    ...
    ec2NodeClasses:
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 80Gi
            volumeType: gp3
            encrypted: true
      }
    }
  }
  ...
}
```
