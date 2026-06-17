# Libvirt VM test harness

Boots **official Ubuntu cloud images** under libvirt via cloud-init, then runs the
repo's `deploy.yml` over SSH against real Ubuntu **22.04 / 24.04 / 26.04** VMs.
Complements the Docker build test (root `Makefile` / `Dockerfile`) by exercising a
real OS: systemd, real `apt`/snap, version-keyed installers (AFNI/ANTs use
`ansible_distribution*`), and clean-VM idempotence.

## Host prerequisites (one-time)

Tools: `qemu-kvm`, `libvirt`, `virt-install`, `cloud-image-utils` (`cloud-localds`),
`qemu-utils`/`qemu-img`, `acl` (`setfacl`), `wget`, and
[`uv`](https://docs.astral.sh/uv/).

```bash
# Debian/Ubuntu
sudo apt install qemu-kvm libvirt-daemon-system virtinst cloud-image-utils qemu-utils acl wget
# Arch / CachyOS
sudo pacman -S qemu-full libvirt virt-install cloud-image-utils acl wget uv
```

Then:

```bash
sudo usermod -aG libvirt "$USER"          # log out/in after this
sudo systemctl enable --now libvirtd
sudo virsh net-start default && sudo virsh net-autostart default
make host-setup                            # one-time: VM-disk dir + ACL (uses sudo)
make deps-check                            # validates the above
```

Uses `qemu:///system` with the libvirt `default` NAT network so the VM gets an IP
reachable from the host. The hypervisor runs VMs as the unprivileged
`libvirt-qemu` user, which can't read `$HOME` (mode 700), so `host-setup` creates
a VM-disk dir (`IMAGES=/var/lib/libvirt/images/neuroansible`) you own with an ACL
granting `libvirt-qemu` read access — after that, `vm-*` need no sudo. Override
`LIBVIRT_DEFAULT_URI` / `NET` / `IMAGES` / `QEMU_USER` if your host differs.

## Workflow

```bash
make host-setup                 # one-time (see prerequisites)
make venv                       # uv venv: ansible + mambaorg.micromamba role
make vm-up      DISTRO=24.04    # download image, cloud-init, boot, write inventory-24.04
make vm-snapshot DISTRO=24.04   # snapshot the clean base (pre-playbook)
make vm-test    DISTRO=24.04    # run deploy.yml twice (install + idempotence) + verify dirs
make vm-revert  DISTRO=24.04    # roll back to clean base for the next iteration
make vm-ssh     DISTRO=24.04    # shell into the VM
make vm-destroy DISTRO=24.04    # tear down + reclaim storage

make test-all                   # up+snapshot+test across DISTROS, prints PASS/FAIL summary
make test-all CLEAN=1           # ...and destroy each VM afterwards
```

Dev loop: `vm-up` → `vm-snapshot` once, then iterate `vm-test` → `vm-revert` →
edit playbook → `vm-test` without re-downloading or rebuilding the base.

## Knobs

| Var | Default | Notes |
|-----|---------|-------|
| `DISTRO` | `24.04` | one of `22.04 24.04 26.04` |
| `DISTROS` | `22.04 24.04 26.04` | matrix for `test-all` |
| `TAGS` | `--skip-tags resources` | e.g. `TAGS="--tags ants,fsl"` |
| `RAM` | `8192` (MB) | |
| `VCPUS` | `4` | |
| `DISK_SIZE` | `60G` | skip-resources install ≈20GB |
| `CLEAN` | unset | `1` => `test-all` destroys VMs after |

## Caveats

- **26.04** cloud image publishes April 2026; `vm-up` fails fast with a clear
  message if the release URL 404s.
- **`nvidia` / `matlab*`** tags are gated `[never,...]` (GPU passthrough / licensing)
  and are not run here.
- A full skip-resources install is large and slow (~20GB, tens of minutes per VM).
- `cache/` (cloud images, generated SSH key, seeds) and `inventory-*` are gitignored.
