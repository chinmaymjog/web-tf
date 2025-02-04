FROM ubuntu
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    sudo \
    python3-pymysql \
    mysql-client \
    fontconfig \
    openjdk-17-jre \
    software-properties-common && \
    ssh-keygen -A && \
    useradd -m azureuser && \
    mkdir /run/sshd /home/azureuser/.ssh && \
    echo "azureuser ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/azureuser && \
    wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key && \
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null && \
    apt-get update && \
    apt-get install jenkins -y && \
    echo "jenkins ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/jenkins && \
    add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get update && \
    apt-get install ansible -y

COPY --chown=azureuser:azureuser --chmod=600 ./sshkey/azureuser_rsa.pub /home/azureuser/.ssh/authorized_keys
COPY --chown=azureuser:azureuser --chmod=600 ./sshkey/azureuser_rsa /home/azureuser/id_rsa

COPY entrypoint.sh ./

EXPOSE 22 8080
ENTRYPOINT [ "./entrypoint.sh" ]