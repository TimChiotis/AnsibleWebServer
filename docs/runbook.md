# Runbook — de volledige keten

Dit runbook beschrijft hoe je de omgeving van een groep **opbouwt**, **controleert** en **afbreekt**.
Het is dezelfde procedure die Jenkins later uitvoert.

## Wat er gebouwd wordt

| Machine | Type | Draait | Naam |
|---|---|---|---|
| web1 | t3.micro | nginx, node_exporter | `web1.groepN.example.tld` |
| web2 | t3.micro | apache2, node_exporter | `web2.groepN.example.tld` |
| monitoring1 | t3.small | Prometheus, Grafana, node_exporter | `monitoring1.groepN.example.tld` |

Grafana (`:3000`) en Prometheus (`:9090`) zijn alleen bereikbaar vanaf `my_ip_cidr`.
De webservers zijn voor iedereen bereikbaar op poort 80.

## Beperking: één eigenaar per groep

- De AWS-resources staan in het Learner Lab-account van de student die `up.sh` uitvoert.
- De Terraform-state staat **lokaal** bij die student (`terraform/terraform.tfstate`).
- Een ander groepslid kan die omgeving **niet** beheren door alleen de repo te clonen:
  zijn state is leeg, en zijn credentials horen bij een ander AWS-account.
- Spreek per groep af wie de omgeving beheert. De anderen werken via branches en PR's.
- Een Jenkins-pipeline heeft later een AWS-identiteit én een gedeelde state nodig. Dat wordt in fase H beslist.

## Wat niet in git staat

| Bestand of toestand | Waarom niet in git | Hoe je het krijgt |
|---|---|---|
| `~/.aws/credentials` | tijdelijke credentials, verlopen na elke sessie | Learner Lab → **AWS Details** → *AWS CLI*, elke sessie opnieuw plakken |
| `~/.ssh/aws-lab` en `.pub` | privésleutel | eenmalig: `ssh-keygen -t ed25519 -f ~/.ssh/aws-lab` (fase A) |
| `~/.ssh/ansible` en `.pub` | privésleutel van de gebruiker `ansible` | uit de Ansible-les |
| `~/.vault_pass` | ontsleutelt `ansible/vault/*.yml` | één groepslid maakt het aan en geeft het persoonlijk door; `chmod 600` |
| Ansible-collections (`community.general`, `ansible.posix`) | zitten in het Debian-pakket `ansible`, of in `~/.ansible/collections/` | controleren: `ansible-galaxy collection list`; ontbreken ze: `ansible-galaxy collection install -r ansible/collections/requirements.yml` |
| `terraform/terraform.tfstate*` | toestand van één AWS-account, kan gevoelige gegevens bevatten | Terraform maakt en beheert het (`up.sh`, stap 3) |
| `terraform/.terraform/` | gedownloade providers | `terraform init` (`up.sh`, stap 2) |
| `ansible/inventory/hosts.yml` | hangt af van de huidige IP's | `up.sh`, stap 4 |
| `~/.ssh/known_hosts_aws` | host keys van machines die weer verdwijnen | automatisch (`accept-new`); `down.sh` verwijdert het |

## Wat er na een clone wél is

- `terraform/`: de configuratie en `.terraform.lock.hcl` (vaste providerversie).
- `ansible/`: roles, playbooks, `group_vars`, en de **versleutelde** `vault/gandi.yml` en `vault/grafana.yml`.
- `ansible/roles/grafana/files/dashboards/node-exporter-full.json`: dashboard 1860, revisie 45.
- `scripts/`: `check-controller.sh`, `up.sh`, `down.sh`, `fetch-dashboard.py`.

## Eenmalig per controller

1. Pakketten: `awscli`, `terraform`, `ansible`, `git`, `curl`, `python3` en `bind9-dnsutils` (voor `dig`).
2. De sleutels `~/.ssh/aws-lab`, `~/.ssh/ansible` en de GitHub-sleutel in de agent (keychain in `~/.bashrc`).
3. De collections controleren (zie de tabel hierboven).
4. `~/.vault_pass` met het wachtwoord van de groep.
5. De repo clonen via de alias `github-school`.

## Bij het begin van elke sessie

1. Learner Lab: **Start Lab**, wachten op het groene bolletje.
2. **AWS Details** → *AWS CLI* → plakken in `~/.aws/credentials`.
3. `./scripts/check-controller.sh`: zes keer `[OK]`.

## Opbouwen: `scripts/up.sh`

~~~
./scripts/up.sh
~~~

| Stap | Wat | Als deze stap faalt |
|---|---|---|
| 1 | controller-check | er is niets veranderd |
| 2 | `terraform init` | er is niets veranderd |
| 3 | `terraform apply` | resources kunnen (deels) bestaan |
| 4 | inventory uit `terraform output` | resources bestaan |
| 5 | wachten op SSH | resources bestaan |
| 6 | bootstrap (als `admin`) | resources bestaan |
| 7 | `site.yml` | resources bestaan, deels ingericht |
| 8 | `dns.yml` | alles ingericht, DNS (deels) niet |
| 9 | `verify.yml` | alles gebouwd, maar iets werkt niet |

- Bij een fout stopt `up.sh` meteen, meldt de stap en geeft een exitcode verschillend van 0.
  Er wordt **niets** afgebroken: je kunt de fout onderzoeken.
- `up.sh` is idempotent: na het oplossen van een fout voer je het gewoon opnieuw uit.
- Duur (gemeten): **ongeveer 6 minuten** vanaf nul, **ongeveer 3 minuten** op een bestaande omgeving.
- `TF_VAR_my_ip_cidr` wordt bepaald met `checkip.amazonaws.com`, tenzij de variabele al gezet is.

## Controleren: `ansible/verify.yml`

~~~
cd ansible && ansible-playbook verify.yml
~~~

| Controle | Bewijst |
|---|---|
| DNS bij de nameserver van Gandi | de namen wijzen naar de IP's uit `terraform output` |
| web1 / web2 via de naam | HTTP 200 met `Server: nginx` / `Server: Apache` |
| Prometheus `/api/v1/targets` | alle machines worden opgehaald en staan op `up` |
| Grafana `/api/health` | Grafana en zijn database werken |
| Datasource-health | Grafana bereikt Prometheus |
| Dashboard via de API | Grafana heeft het dashboard **geladen** uit provisioning |
| Geen `${DS_…}` | het geladen dashboard heeft geen open verwijzingen |
| Query via Grafana | Grafana krijgt echte data van Prometheus |

Elke controle wordt tot 12 keer herhaald, met 15 seconden ertussen. Snel testen kan met
`-e verify_retries=1 -e verify_delay=1`.

## Afbreken: `scripts/down.sh`

~~~
./scripts/down.sh
~~~

| Stap | Wat | Als deze stap faalt |
|---|---|---|
| 1 | controller-check | er is niets veranderd |
| 2 | DNS-records verwijderen (`dns.yml -e dns_state=absent`) | er is **niets** afgebroken; de records wijzen nog naar je eigen machines |
| 3 | `terraform destroy` | de records zijn weg; `down.sh` opnieuw uitvoeren |
| 4 | controle in AWS op naam: instances, security groups, key pair | er staat nog iets; de lijst staat in de uitvoer |

- Duur (gemeten): **ongeveer 1 minuut**.
- Is de state leeg, dan slaat `down.sh` stap 2 en 3 over en doet het alleen de controle. Twee keer opruimen is dus veilig.

## Als het misloopt

| Wat je ziet | Oorzaak | Wat je doet |
|---|---|---|
| `[FOUT] AWS-credentials geldig` | de sessie is verlopen | credentials opnieuw plakken, `up.sh` of `down.sh` opnieuw |
| `Invalid value for variable` bij `my_ip_cidr` | verkeerde waarde in `TF_VAR_my_ip_cidr` | `unset TF_VAR_my_ip_cidr` en opnieuw |
| stap 5 hangt of `UNREACHABLE` | je publieke IP is veranderd (ander netwerk) | `unset TF_VAR_my_ip_cidr` en `up.sh` opnieuw: stap 3 past de security groups aan |
| `No public IP for …` in stap 8 | de machines zijn gestopt (einde van de sessie) | zie *De sessie stopte halverwege* |
| verify faalt | een service werkt niet | lees welke controle faalt; herstel met `up.sh` (dat voert ook `site.yml` uit) |
| `down.sh` faalt in stap 2 | credentials, vault of Gandi | oplossen en `down.sh` opnieuw; er is niets afgebroken |
| `down.sh` faalt in stap 4 | er staat nog iets in AWS | `down.sh` opnieuw, of in de console verwijderen |

### De sessie stopte halverwege

Het Learner Lab stopt alle machines na 4 uur, ook midden in `up.sh`. Het start ze niet altijd vanzelf opnieuw.

~~~
IDS=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=stopped" \
  "Name=tag:Name,Values=web1,web2,monitoring1" --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 start-instances --instance-ids $IDS
aws ec2 wait instance-running --instance-ids $IDS
terraform -chdir=terraform apply -refresh-only -auto-approve
./scripts/up.sh
~~~

Voer `-refresh-only` **nooit** uit terwijl de machines gestopt zijn: dan komen er lege IP's in de state.

## Het dashboard bijwerken

1. Pas `REVISION` aan in `scripts/fetch-dashboard.py`.
2. `./scripts/fetch-dashboard.py`: het script controleert de uid, de placeholders en de datasource-variabele.
3. Kijk de diff na in een PR en voer daarna `up.sh` uit.
