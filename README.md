# NeuroAnsible

An ansible playbook to deploy a complete standalone neuroimaging workstation.

## Sponsorship

This software is developed and supported by [Gabriel Devenyi Consulting](https://gabriel.devenyi.ca/consulting/).

To request support in the use of this deployment software, or request additional software be added, please contact us.

## Prerequisites

This ansible playbook was developed on Ubuntu 22.04 and 24.04 and likely works on all
variants (Ubuntu, Kubuntu, Lubuntu, etc.)

Prerequiste to use this playbook is installation of ansible.

Total installation size as of 2024-05-24 is approximately 110GB.

## Software Requirements

This playbook uses [ansible](https://www.ansible.com/) to deploy on the machine
controlling the setup. This machine does not need to be the machine that will
ultimately be the setup workstation.

See the [Ansible installation guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html).

Once ansible is installed, you will need to pull in a external role used by this package:

```bash
$ ansible-galaxy role install mambaorg.micromamba
```

## Use

Clone a copy of the repository and run the ansible playbook

You must have `sudo` access to make chages to the system.

Now you can setup the system by running the ansible playbook:
```bash
$ ansible-playbook --ask-become-pass deploy.yml
```

Ansible will prompt you for a `sudo` password (`--ask-become-pass`).
If you have passwordless sudo you can omit this.

## Customize Software

The playbook is customizable with `tags`, by default all tags are executed.

See `ansible-playbook --list-tags deploy.yml` for tags available to limit execution.

You can either select specific tags with `--tags` as an option to the playbook call,
or skip specific tasks with `--skip-tags`

## Using the installed software

All software is installed using the `lmod` module system. Once deployment is complete
the next time a terminal is opened, the command `module avail` will list the
software which can be used. Use `module load` to make a specific package available
in the terminal.
