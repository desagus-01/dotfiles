#!/usr/bin/env bash
set -euo pipefail

ANSIBLE_DIR="${HOME}/.config/ansible"

cd "${ANSIBLE_DIR}" || exit 1

ansible-playbook packages.yml -K -vv
ansible-playbook bootstrap.yml -K -vv
