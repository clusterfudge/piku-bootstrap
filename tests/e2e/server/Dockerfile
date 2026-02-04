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
COPY tests/e2e/server/bootstrap-piku.sh /root/bootstrap-piku.sh
RUN chmod +x /root/bootstrap-piku.sh
COPY tests/e2e/server/piku-bootstrap.service /etc/systemd/system/piku-bootstrap.service

RUN systemctl enable ssh && systemctl enable piku-bootstrap

# Create entrypoint that writes runtime env vars before starting systemd
COPY tests/e2e/server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]