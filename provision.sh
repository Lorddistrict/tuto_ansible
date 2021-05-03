#!/bin/sh

# Paranoia mode
set -e
set -u

# Je récupere le hostname du serveur
HOSTNAME="$(hostname)"

## Verifier que la paire de clefs est presente avant de continuer
if [ ! -f /vagrant/ansible_rsa ]; then
	>&2 echo "ERROR: unable to find /vagrant/ansible_rsa keyfile"
	exit 1
fi
if [ ! -f /vagrant/ansible_rsa.pub ]; then
	>&2 echo "ERROR: unable to find /vagrant/ansible_rsa.pub keyfile"
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Mettre à jour le catalogue des paquets debian
apt-get update

# Installer les prérequis pour ansible
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    git \
    curl \
    wget \
    vim \
    gnupg2 \
    python3 \
    software-properties-common


# Si la machine s'appelle control
if [ "$HOSTNAME" = "control" ]; then
	# J'installe ansible dessus
	apt-get install -y \
		ansible	

	# J'ajoute les deux clefs sur le noeud de controle
	mkdir -p /root/.ssh
	cp /vagrant/ansible_rsa /home/vagrant/.ssh/ansible_rsa
	cp /vagrant/ansible_rsa.pub /home/vagrant/.ssh/ansible_rsa.pub
	chmod 0600 /home/vagrant/.ssh/*_rsa
	chown -R vagrant:vagrant /home/vagrant/.ssh

	# Utilisation du SSH-AGENT pour charger les clés une fois pour toute
	# et ne pas avoir à retaper les password des clefs
	sed -i \
		-e '/## BEGIN PROVISION/,/## END PROVISION/d' \
		/home/vagrant/.bashrc
	cat >> /home/vagrant/.bashrc <<-MARK
	## BEGIN PROVISION
	eval \$(ssh-agent -s)
	ssh-add ~/.ssh/ansible_rsa
	## END PROVISION
	MARK
fi

# J'utilise /etc/hosts pour associer les IP aux noms de domaines
# sur mon réseau local, sur chacune des machines
sed -i \
	-e '/^## BEGIN PROVISION/,/^## END PROVISION/d' \
	/etc/hosts
cat >> /etc/hosts <<MARK
## BEGIN PROVISION
192.168.50.250      control
192.168.50.10       server0
192.168.50.20       server1
192.168.50.30       server2
## END PROVISION
MARK

# J'autorise la clef sur tous les serveurs
mkdir -p /root/.ssh
cat /vagrant/ansible_rsa.pub >> /root/.ssh/authorized_keys

# Je vire les duplicata (potentiellement gênant pour SSH)
sort -u /root/.ssh/authorized_keys > /root/.ssh/authorized_keys.tmp
mv /root/.ssh/authorized_keys.tmp /root/.ssh/authorized_keys

# Je corrige les permissions
touch /root/.ssh/config
chmod 0600 /root/.ssh/*
chmod 0644 /root/.ssh/config
chmod 0700 /root/.ssh
chown -R vagrant:vagrant /home/vagrant/.ssh

echo "SUCCESS."