#!/usr/bin/env bash
# Build, configure and verify the whole environment of this group.
# Safe to run again: every step is idempotent.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

STEPS=9
STEP=0
CURRENT=""

step() {
  STEP=$((STEP + 1))
  CURRENT="$1"
  echo
  echo "=== [STAP ${STEP}/${STEPS}] ${CURRENT} ==="
}

on_error() {
  local code=$?
  trap - ERR
  echo >&2
  echo "!!! up.sh mislukt in stap ${STEP}/${STEPS}: ${CURRENT} (exitcode ${code})" >&2
  if [ "$STEP" -ge 3 ]; then
    echo "!!! Er kunnen AWS-resources bestaan. Er is NIETS afgebroken." >&2
    echo "!!! Los de fout op en voer scripts/up.sh opnieuw uit," >&2
    echo "!!! of ruim alles op met scripts/down.sh." >&2
  else
    echo "!!! Er is nog niets in AWS veranderd." >&2
    echo "!!! Los de fout op en voer scripts/up.sh opnieuw uit." >&2
  fi
  exit "$code"
}
trap on_error ERR

step "Controller-check"
check_output="$(./scripts/check-controller.sh)"
echo "$check_output"
if grep -q '\[FOUT\]' <<< "$check_output"; then
  false
fi

step "Terraform init"
export TF_VAR_my_ip_cidr="${TF_VAR_my_ip_cidr:-$(curl -fsS https://checkip.amazonaws.com)/32}"
echo "my_ip_cidr = ${TF_VAR_my_ip_cidr}"
terraform -chdir=terraform init -input=false

step "Terraform apply"
terraform -chdir=terraform apply -auto-approve -input=false

step "Inventory uit terraform output"
cd ansible
{ echo '---'; terraform -chdir=../terraform output -raw ansible_inventory; } > inventory/hosts.yml
ansible-inventory --graph

step "Wachten op SSH"
ansible all -e ansible_user=admin --private-key ~/.ssh/aws-lab -m ansible.builtin.wait_for_connection

step "Bootstrap"
ansible-playbook bootstrap.yml -e ansible_user=admin --private-key ~/.ssh/aws-lab

step "Configuratie (site.yml)"
ansible-playbook site.yml

step "DNS (dns.yml)"
ansible-playbook dns.yml

step "Controle (verify.yml)"
ansible-playbook verify.yml

trap - ERR
echo
echo "=== up.sh klaar in $((SECONDS / 60))m$((SECONDS % 60))s: alle controles groen ==="
terraform -chdir=../terraform output monitoring_urls
