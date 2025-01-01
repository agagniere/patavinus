# Run a prod-like cluster on local machine

## Local PostgreSQL

```shell
zig build run
```

## Using k3d

```shell
sudo k3d cluster create \
	--config k3d-options.yaml \
	--kubeconfig-update-default \
	--kubeconfig-switch-context
```

(then many steps to be documented)

## Failed attempt to use compose on Apple sillicon macOS

```shell
# From repo root
zig build -Dtarget=aarch64-linux-musl
podman compose -f dev/compose.yaml build
podman compose up
```
