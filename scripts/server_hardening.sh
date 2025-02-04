#!/bin/bash

set -e  # Exit on error

## Provisioner log file
logfile=/var/log/provisioner.log

## Function to echo action with timestamp
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | sudo tee -a "$logfile"
}

log "Updating Operating System"
sudo apt-get update -qq
touch /var/run/reboot-required

log "Installing basic packages for smooth system functioning"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bash-completion fail2ban lvm2 nfs-common

log "Add time stamp to history"
echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "' | sudo tee -a /root/.bashrc

cat <<EOF | sudo tee /etc/mybanner
########################################################################
# Authorized access only!
# If you are not authorized to access or use this system, disconnect now!
########################################################################
EOF

log "Securing SSH"
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat <<EOF | sudo tee /etc/ssh/sshd_config
AuthorizedKeysFile .ssh/authorized_keys
Protocol 2
Banner /etc/mybanner
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers azureuser
X11Forwarding no
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
EOF

sudo systemctl reload ssh.service

log "Enabling firewall & allowing SSH, HTTP, HTTPS services"
sudo ufw --force enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

log "Enabling and configuring fail2ban to protect SSH against DDoS"
sudo systemctl enable --now fail2ban.service

cat <<EOF | sudo tee /etc/fail2ban/jail.local
[sshd]
enabled = true
filter = sshd
bantime = 30m
findtime = 30m
maxretry = 5
EOF

log "Restarting fail2ban"
sudo systemctl restart fail2ban.service

log "Provisioning completed successfully."