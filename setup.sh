# Update package lists and install Docker
sudo apt-get update
sudo apt install docker.io
sudo usermod -aG docker rancher
sudo chown root:docker /var/run/docker.sock


# K3s installation
curl -sfL https://get.k3s.io | sh -

# k3s.yamlのグループを現在のユーザーに変更
sudo chown $(whoami) /etc/rancher/k3s/k3s.yaml

# ファイルを一般ユーザーが読み取れるようにする
sudo chmod 600 /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
source ~/.bashrc

# Helm installation and repository setup
sudo snap install helm --classic

# Cert-manager setup

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

# Rancher installation
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
# 現在のIPアドレスを取得
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Rancher のインストール
helm install rancher rancher-latest/rancher --namespace cattle-system \
  --set hostname=${IP_ADDRESS}.sslip.io --set replicas=1 --set bootstrapPassword=admin

# TLS setup using OpenSSL
sudo openssl genpkey -algorithm RSA -out tls.key
sudo openssl req -new -key tls.key -out tls.csr
sudo openssl x509 -req -in tls.csr -signkey tls.key -out tls.crt -days 365
sudo kubectl create secret tls tls-rancher --cert=tls.crt --key=tls.key -n cattle-system

# longhorn
sudo apt install -y open-iscsi
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
