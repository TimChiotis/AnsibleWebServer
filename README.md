# ansible-web
Ansible project that configures two Debian 13 web servers:
web1 runs nginx (role `nginx`), web2 runs apache2 (role `apache`).
## Usage
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook bootstrap.yml -K # once, creates the ansible user
ansible-playbook site.yml
## Quality
ansible-lint
