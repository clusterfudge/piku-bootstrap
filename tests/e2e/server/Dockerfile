# Piku Server Dockerfile
FROM jrei/systemd-ubuntu:22.04

RUN apt-get update && apt-get install -y curl git openssh-server sudo && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config  
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
RUN ssh-keygen -A

COPY piku-bootstrap /root/piku-bootstrap
COPY playbooks /root/playbooks

RUN systemctl enable ssh

EXPOSE 22
CMD ["/lib/systemd/systemd"]
