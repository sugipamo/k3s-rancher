#!/bin/bash

# Update package lists and install Docker
sudo apt-get update
sudo apt install -y docker.io
sudo usermod -aG docker $CURRENT_USER
sudo chown root:docker /var/run/docker.sock


# Detect the host IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Start a local Docker Registry on port 5000
docker run -d --restart=always --name registry -p 5000:5000 registry:2

# Wait for the registry to start
sleep 5

# Create registries.yaml for K3s
sudo mkdir -p /etc/rancher/k3s
cat <<EOF | sudo tee /etc/rancher/k3s/registries.yaml
mirrors:
  "${IP_ADDRESS}:5000":
    endpoint:
      - "http://${IP_ADDRESS}:5000"
EOF

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Update permissions for k3s.yaml
sudo chown $(whoami) /etc/rancher/k3s/k3s.yaml
sudo chmod 600 /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
source ~/.bashrc

# Install Helm
sudo snap install helm --classic

# Cert-manager setup
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

# Install Rancher
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
helm install rancher rancher-latest/rancher --namespace cattle-system \
  --set hostname=${IP_ADDRESS}.sslip.io --set replicas=1 --set bootstrapPassword=admin

# TLS setup using OpenSSL
sudo openssl genpkey -algorithm RSA -out tls.key
sudo openssl req -new -key tls.key -out tls.csr
sudo openssl x509 -req -in tls.csr -signkey tls.key -out tls.crt -days 365
sudo kubectl create secret tls tls-rancher --cert=tls.crt --key=tls.key -n cattle-system

# Longhorn setup
sudo apt install -y open-iscsi
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace

echo "Setup complete. Local Docker Registry running at http://${IP_ADDRESS}:5000"
