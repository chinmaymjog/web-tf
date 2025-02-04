#!/bin/bash
## Provisioner log file
logfile=/var/log/provisioner.log
## Function to echo action with time stamp
log() {
    echo "$(date +'%X %x') $1" | sudo tee -a $logfile
}

log "Updating Operating System"
sudo apt-get update
sleep 15
log "Installing basic packages for smooth system functioning"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bash-completion fail2ban

log "System hardening"
echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "' | sudo tee -a /root/.bashrc
echo "
########################################################################
# Authorized access only!
# If you are not authorized to access or use this system, disconnect now!
########################################################################
"| sudo tee /etc/mybanner

log "Securing SSH"
sudo mv /etc/ssh/sshd_config /etc/ssh/sshd_config_org
echo "AuthorizedKeysFile .ssh/authorized_keys
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
" | sudo tee /etc/ssh/sshd_config

sudo systemctl reload sshd.service

log "Enableing firewall & allow SSH, HTTP, HTTPS services"
echo "y" | sudo ufw enable
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443

log "Enableing fail2ban & configure it to protect SSH against DDOS"
sudo systemctl enable fail2ban.service

echo "[sshd]
enabled = true
filter = sshd
bantime = 30m
findtime = 30m
maxretry = 5
" | sudo tee /etc/fail2ban/jail.local

log "Restarting fail2ban"
sudo systemctl restart fail2ban.service
