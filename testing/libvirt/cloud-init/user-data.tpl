#cloud-config
hostname: @HOSTNAME@
fqdn: @HOSTNAME@.test
manage_etc_hosts: true

users:
  - name: ubuntu
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: [sudo]
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - @PUBKEY@

# Ansible needs python3; qemu-guest-agent lets the host read the VM IP reliably.
package_update: true
packages:
  - qemu-guest-agent
  - python3

runcmd:
  - [systemctl, enable, --now, qemu-guest-agent]

# Grow the rootfs to fill the resized overlay disk.
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true
