#!/bin/bash

set -e  # Exit on error

sudo apt update -qq
sudo apt install -y -qq software-properties-common fontconfig openjdk-17-jre

## Add Ansible repository
sudo add-apt-repository --yes --update ppa:ansible/ansible

## Add Jenkins repository key
sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

## Install Ansible & Jenkins
sudo apt update -qq
sudo apt install -y -qq ansible jenkins

## Configure sudo privileges for Jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins

## Enable and start Jenkins service
sudo systemctl enable --now jenkins