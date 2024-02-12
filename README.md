# NeuroAnsible

An ansible playbook to deploy a complete standalone neuroimaging workstation.

## Sponsorship

This software is developed and supported by [Gabriel Devenyi Consulting](https://gabriel.devenyi.ca/consulting/).

To request support in the use of this deployment software, or request additional software be added, please contact us.

## Prerequisites

This ansible playbook was developed on Ubuntu 22.04 and likely works on all 22.04
variants (Ubuntu, Kubuntu, Lubuntu, etc.)

Prerequiste to use this playbook is SSH access to a workstation you wish to configure.

## Software Requirements

This playbook uses [https://www.ansible.com/](ansible) to deploy on the machine
controlling the setup. This machine does not need to be the machine that will
ultimately be the setup workstation.

See the [https://docs.ansible.com/ansible/latest/installation_guide/index.html](Ansible installation guide)

Once ansible is installed, you will need to pull in a external role used by this package:

```bash
$ ansible-galaxy role install mambaorg.micromamba
```

The workstation you wish to setup will need OpenSSH server installed for access:
```bash
$ apt install openssh-server -y
```

## Use

Add to the `[workstations]` section of the `inventory` file the IP address or Hostname
of the system you wish to setup, along with `ansible_user=<username>` to specify
the username which has SSH access to the system. This user must also have `sudo` access.

Now you can setup the system by running the ansible playbook:
```bash
$ ansible-playbook deploy.yml -K -k
```

Ansible will prompt you for a login password (`-k`) and `sudo` password (`-K`).
If you have setup ssh keys or your user has passwordless sudo you can omit those.

## Customize Software

The playbook is customizable with `tags`, by default all tags are executed.

See `ansible-playbook --list-tags deploy.yml` for tags available to limit execution.