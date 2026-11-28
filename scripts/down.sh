#!/usr/bin/env bash
# Remove the DNS records of this group, destroy the AWS resources
# and check that nothing is left behind.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

STEPS=4
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
  echo "!!! down.sh mislukt in stap ${STEP}/${STEPS}: ${CURRENT} (exitcode ${code})" >&2
  case "$STEP" in
    1) echo "!!! Er is niets veranderd. Los de fout op en voer scripts/down.sh opnieuw uit." >&2 ;;
    2) echo "!!! De DNS-records konden niet verwijderd worden. Er is NIETS afgebroken:" >&2
       echo "!!! de machines draaien nog en de records wijzen naar je eigen machines." >&2
       echo "!!! Los de fout op (credentials? vault? Gandi?) en voer scripts/down.sh opnieuw uit." >&2 ;;
    3) echo "!!! De DNS-records zijn al weg, maar terraform destroy faalde." >&2
       echo "!!! Voer scripts/down.sh opnieuw uit: destroy kan veilig herhaald worden." >&2 ;;
    4) echo "!!! Er staan nog resources in AWS (zie hierboven)." >&2
       echo "!!! Voer scripts/down.sh opnieuw uit, of verwijder ze in de AWS-console." >&2 ;;
  esac
  exit "$code"
}
trap on_error ERR

step "Controller-check"
check_output="$(./scripts/check-controller.sh)"
echo "$check_output"
if grep -q '\[FOUT\]' <<< "$check_output"; then
  false
fi
export TF_VAR_my_ip_cidr="${TF_VAR_my_ip_cidr:-$(curl -fsS https://checkip.amazonaws.com)/32}"

if [ -n "$(terraform -chdir=terraform state list 2>/dev/null)" ]; then
  step "DNS-records verwijderen"
  (cd ansible && ansible-playbook dns.yml -e dns_state=absent)

  step "Terraform destroy"
  terraform -chdir=terraform destroy -auto-approve -input=false
  rm -f ~/.ssh/known_hosts_aws
else
  step "DNS-records verwijderen"
  echo "De Terraform-state is leeg: er zijn geen records van deze omgeving bekend."
  step "Terraform destroy"
  echo "De Terraform-state is leeg: er is niets om af te breken."
fi

step "Controle in AWS: is alles weg?"
left=""
instances="$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web1,web2,monitoring1" \
            "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
groups="$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=web-sg,monitoring-sg" \
  --query 'SecurityGroups[].GroupName' --output text)"
keys="$(aws ec2 describe-key-pairs \
  --filters "Name=key-name,Values=aws-lab" \
  --query 'KeyPairs[].KeyName' --output text)"
if [ -n "$instances" ]; then left="${left} instances: ${instances};"; fi
if [ -n "$groups" ]; then left="${left} security groups: ${groups};"; fi
if [ -n "$keys" ]; then left="${left} key pairs: ${keys};"; fi
if [ -n "$left" ]; then
  echo "Nog aanwezig in AWS:${left}" >&2
  false
fi
echo "Geen instances, security groups of key pairs van deze omgeving meer in AWS."

trap - ERR
echo
echo "=== down.sh klaar in $((SECONDS / 60))m$((SECONDS % 60))s: alles opgeruimd ==="
