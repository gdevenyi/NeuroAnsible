# NeuroAnsible — libvirt VM test harness
#
# Boots official Ubuntu cloud images under libvirt via cloud-init, then runs the
# repo's deploy.yml over SSH against real Ubuntu 22.04 / 24.04 / 26.04 VMs.
#
# Quick start:
#   make deps-check                 # verify host tooling + libvirt network
#   make venv                       # uv venv with ansible + micromamba role
#   make vm-up      DISTRO=24.04    # boot + cloud-init a fresh VM
#   make vm-snapshot DISTRO=24.04   # snapshot the clean base
#   make vm-test    DISTRO=24.04    # run deploy.yml (twice: install + idempotence)
#   make vm-revert  DISTRO=24.04    # roll back to clean base
#   make vm-destroy DISTRO=24.04    # tear down + reclaim storage
#   make test-all                   # up+snapshot+test across all DISTROS
#
# Override knobs: DISTRO, RAM, VCPUS, DISK_SIZE, TAGS, DISTROS, CLEAN=1

SHELL := /bin/bash
.ONESHELL:
.PHONY: help host-setup deps-check venv vm-up vm-snapshot vm-test vm-revert \
        vm-destroy vm-ip vm-ssh test-all clean-cache

# ---- Tunables ---------------------------------------------------------------
DISTRO     ?= 24.04
DISTROS    ?= 22.04 24.04 26.04
RAM        ?= 8192
VCPUS      ?= 4
DISK_SIZE  ?= 60G
TAGS       ?= --skip-tags resources
NET        ?= default
export LIBVIRT_DEFAULT_URI ?= qemu:///system
# Where the hypervisor reads VM disks. qemu runs as unprivileged libvirt-qemu and
# cannot traverse $HOME (mode 700), so runtime disks live here, not in cache/.
# `make host-setup` creates this dir + an ACL granting libvirt-qemu read access.
IMAGES     ?= /var/lib/libvirt/images/neuroansible
QEMU_USER  ?= libvirt-qemu
SUDO       ?= sudo

# ---- Derived paths ----------------------------------------------------------
HERE      := $(CURDIR)
REPO      := $(abspath $(HERE)/../..)
CACHE     := $(HERE)/cache
VENV      := $(HERE)/.venv
ANSIBLE   := $(VENV)/bin/ansible
APLAYBOOK := $(VENV)/bin/ansible-playbook
AGALAXY   := $(VENV)/bin/ansible-galaxy

VM        := neuroansible-test-$(DISTRO)
IMG_URL   := https://cloud-images.ubuntu.com/releases/$(DISTRO)/release/ubuntu-$(DISTRO)-server-cloudimg-amd64.img
BASE_IMG  := $(CACHE)/ubuntu-$(DISTRO)-server-cloudimg-amd64.img
OVERLAY   := $(IMAGES)/$(DISTRO).qcow2
SEED      := $(IMAGES)/seed-$(DISTRO).iso
KEY       := $(CACHE)/id_ed25519
INV       := $(HERE)/inventory-$(DISTRO)

# deploy.yml runs `become: true`; reuse the repo ansible.cfg (free strategy etc.)
export ANSIBLE_CONFIG := $(REPO)/ansible.cfg

# -----------------------------------------------------------------------------
help:
	@sed -n '2,20p' $(firstword $(MAKEFILE_LIST)) | sed 's/^# \?//'

# One-time host prep: a VM-disk dir you own, with a default ACL so the
# unprivileged libvirt-qemu user can read disks created there (no sudo afterward).
host-setup:
	@set -e
	$(SUDO) install -d -o "$$(id -un)" -g "$$(id -gn)" -m 0755 $(IMAGES)
	$(SUDO) setfacl -m u:$(QEMU_USER):rx -m d:u:$(QEMU_USER):rx $(IMAGES)
	echo "OK: $(IMAGES) ready (libvirt-qemu has read access via ACL)."

deps-check:
	@set -e
	missing=0
	for t in qemu-img virt-install virsh cloud-localds uv ssh wget; do
	  if ! command -v $$t >/dev/null 2>&1; then echo "MISSING: $$t"; missing=1; fi
	done
	if [ $$missing -ne 0 ]; then
	  echo ""
	  echo "Install host prerequisites (Debian/Ubuntu):"
	  echo "  sudo apt install qemu-kvm libvirt-daemon-system virtinst cloud-image-utils qemu-utils wget"
	  echo "Arch/CachyOS:"
	  echo "  sudo pacman -S qemu-full libvirt virt-install cloud-image-utils wget"
	  echo "  (uv: https://docs.astral.sh/uv/  — or pacman -S uv)"
	  exit 1
	fi
	if ! virsh net-info $(NET) >/dev/null 2>&1; then
	  echo "libvirt network '$(NET)' not found. Start it with:"
	  echo "  sudo virsh net-start $(NET) && sudo virsh net-autostart $(NET)"
	  exit 1
	fi
	if [ "$$(virsh net-info $(NET) | awk '/Active/{print $$2}')" != "yes" ]; then
	  echo "libvirt network '$(NET)' is not active: sudo virsh net-start $(NET)"
	  exit 1
	fi
	if [ ! -w $(IMAGES) ]; then
	  echo "VM disk dir $(IMAGES) missing or not writable. Run: make host-setup"; exit 1
	fi
	echo "OK: host tooling present, libvirt URI=$(LIBVIRT_DEFAULT_URI), net '$(NET)' active, IMAGES writable."

venv: $(APLAYBOOK)
$(APLAYBOOK):
	@set -e
	cd $(HERE)
	uv venv $(VENV)
	uv pip install --python $(VENV)/bin/python ansible
	# Same galaxy role the Dockerfile installs.
	$(AGALAXY) role install mambaorg.micromamba

# ---- Lifecycle --------------------------------------------------------------
vm-up: deps-check $(APLAYBOOK)
	@set -e
	mkdir -p $(CACHE)
	if virsh dominfo $(VM) >/dev/null 2>&1; then
	  echo "Domain $(VM) already exists. 'make vm-destroy DISTRO=$(DISTRO)' first."; exit 1
	fi
	# SSH keypair (shared across distros).
	if [ ! -f $(KEY) ]; then ssh-keygen -t ed25519 -N '' -f $(KEY) -C neuroansible-test; fi
	# Cloud image (cached). Fail clearly if the release is not published yet.
	if [ ! -f $(BASE_IMG) ]; then
	  echo "Fetching $(IMG_URL)"
	  if ! wget --spider -q $(IMG_URL); then
	    echo "ERROR: cloud image not available for Ubuntu $(DISTRO) ($(IMG_URL))."
	    echo "       (26.04 publishes April 2026 — check the version/URL.)"; exit 1
	  fi
	  wget -O $(BASE_IMG).part $(IMG_URL) && mv $(BASE_IMG).part $(BASE_IMG)
	fi
	# Standalone per-VM disk (full copy, no backing chain into $HOME) sized to DISK_SIZE.
	# Lives under $(IMAGES) where libvirt-qemu can read it (see host-setup).
	rm -f $(OVERLAY)
	qemu-img convert -f qcow2 -O qcow2 $(BASE_IMG) $(OVERLAY)
	qemu-img resize $(OVERLAY) $(DISK_SIZE)
	# Render cloud-init seed (pubkey has no '|' so it is a safe sed delimiter).
	pub="$$(cat $(KEY).pub)"
	sed -e "s|@PUBKEY@|$$pub|" -e "s|@HOSTNAME@|$(VM)|" cloud-init/user-data.tpl > $(CACHE)/user-data-$(DISTRO)
	sed -e "s|@HOSTNAME@|$(VM)|" cloud-init/meta-data.tpl > $(CACHE)/meta-data-$(DISTRO)
	cloud-localds $(SEED) $(CACHE)/user-data-$(DISTRO) $(CACHE)/meta-data-$(DISTRO)
	# Create + import the domain.
	virt-install \
	  --name $(VM) \
	  --memory $(RAM) --vcpus $(VCPUS) \
	  --osinfo detect=on,name=ubuntu$(DISTRO) \
	  --disk path=$(OVERLAY),format=qcow2,bus=virtio \
	  --disk path=$(SEED),device=cdrom \
	  --network network=$(NET),model=virtio \
	  --graphics none --noautoconsole --import
	$(MAKE) vm-ip DISTRO=$(DISTRO) WAIT=1 >/dev/null
	ip="$$(cat $(CACHE)/ip-$(DISTRO))"
	echo "VM $(VM) at $$ip — waiting for SSH + cloud-init..."
	for i in $$(seq 1 60); do
	  if ssh -i $(KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	       -o ConnectTimeout=5 ubuntu@$$ip 'cloud-init status --wait' 2>/dev/null; then break; fi
	  sleep 5
	done
	sed -e "s|@VMNAME@|$(VM)|" -e "s|@IP@|$$ip|" -e "s|@KEY@|$(KEY)|" inventory.tpl > $(INV)
	echo "Wrote $(INV)"
	$(ANSIBLE) -i $(INV) all -m ping

# Resolve the VM IPv4. WAIT=1 polls until a lease appears; writes cache/ip-<DISTRO>.
vm-ip:
	@set -e
	tries=1; [ "$(WAIT)" = "1" ] && tries=60
	for i in $$(seq 1 $$tries); do
	  ip="$$(virsh domifaddr $(VM) --source lease 2>/dev/null | awk '/ipv4/{print $$4}' | cut -d/ -f1 | head -n1)"
	  if [ -z "$$ip" ]; then
	    ip="$$(virsh domifaddr $(VM) --source agent 2>/dev/null | awk '/ipv4/{print $$4}' | cut -d/ -f1 | grep -v '^127\.' | head -n1)"
	  fi
	  if [ -n "$$ip" ]; then echo "$$ip" | tee $(CACHE)/ip-$(DISTRO); exit 0; fi
	  [ "$(WAIT)" = "1" ] && sleep 5 || break
	done
	echo "Could not determine IP for $(VM)" >&2; exit 1

vm-snapshot:
	@virsh snapshot-create-as $(VM) base "clean post-cloud-init base" --atomic
	@echo "Snapshot 'base' created for $(VM)."

vm-revert:
	@virsh snapshot-revert $(VM) base
	@echo "Reverted $(VM) to 'base'."

vm-test: $(APLAYBOOK)
	@set -e
	test -f $(INV) || { echo "No $(INV); run 'make vm-up DISTRO=$(DISTRO)'"; exit 1; }
	echo "=== Pass 1: deploy ($(TAGS)) ==="
	$(APLAYBOOK) -i $(INV) $(REPO)/deploy.yml $(TAGS)
	echo "=== Pass 2: idempotence check ==="
	out="$$($(APLAYBOOK) -i $(INV) $(REPO)/deploy.yml $(TAGS) 2>&1)"; echo "$$out"
	if echo "$$out" | grep -E 'changed=[1-9]' >/dev/null; then
	  echo "IDEMPOTENCE FAIL: tasks changed on second run."; exit 1
	fi
	echo "Idempotent. Verifying deploy artifacts in VM..."
	ip="$$(cat $(CACHE)/ip-$(DISTRO))"
	ssh -i $(KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$$ip \
	  'test -d /opt/quarantine/software && test -d /opt/quarantine/modulefiles && echo OK: quarantine dirs present'
	echo "PASS: $(DISTRO)"

vm-ssh:
	@ip="$$(cat $(CACHE)/ip-$(DISTRO))"; \
	ssh -i $(KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$$ip

vm-destroy:
	@-virsh destroy $(VM) 2>/dev/null
	@-virsh undefine $(VM) --snapshots-metadata 2>/dev/null
	@rm -f $(OVERLAY) $(SEED) $(INV) $(CACHE)/ip-$(DISTRO) \
	       $(CACHE)/user-data-$(DISTRO) $(CACHE)/meta-data-$(DISTRO)
	@echo "Destroyed $(VM)."

# ---- Matrix -----------------------------------------------------------------
test-all:
	@set -e
	results=""
	for d in $(DISTROS); do
	  echo "############## $$d ##############"
	  if $(MAKE) --no-print-directory vm-up DISTRO=$$d \
	     && $(MAKE) --no-print-directory vm-snapshot DISTRO=$$d \
	     && $(MAKE) --no-print-directory vm-test DISTRO=$$d; then
	    results="$$results\n  $$d: PASS"
	  else
	    results="$$results\n  $$d: FAIL"
	  fi
	  [ "$(CLEAN)" = "1" ] && $(MAKE) --no-print-directory vm-destroy DISTRO=$$d || true
	done
	echo -e "\n===== SUMMARY =====$$results"

clean-cache:
	@rm -rf $(CACHE)
	@echo "Removed $(CACHE) (cloud images, keys, seeds)."
