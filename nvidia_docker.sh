# 以后如果要跑 GPU 容器，只需要补装：nvidia-container-toolkit

# 1. 配置代理服务
export host_ip=$(ip route | grep default | awk '{print $3}')
export HTTP_PROXY="http://${host_ip}:7897"
export HTTPS_PROXY="http://${host_ip}:7897"
export NO_PROXY="localhost,127.0.0.1,*.local,169.254.0.0/16,172.16.0.0/12"


# 2. 给 sudo apt-get 配置临时代理参数 --> aptp
aptp() {
  if [ -n "${HTTP_PROXY:-}" ] && [ -n "${HTTPS_PROXY:-}" ]; then
    sudo apt-get \
      -o Acquire::http::Proxy="$HTTP_PROXY" \
      -o Acquire::https::Proxy="$HTTPS_PROXY" \
      "$@"
  else
    sudo apt-get "$@"
  fi
}

# 3. 添加 nvidia container toolkit下载地址的 官方 GPG key，以及 其下载源地址 到 apt源
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#/deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

aptp update

# 4. 安装
aptp install -y nvidia-container-toolkit

# 5. 配置 docker runtime
sudo nvidia-ctk runtime configure --runtime=docker
# 如果报错，可以尝试
sudo nvidia-ctk runtime configure --runtime=docker --no-cgroups

# 6. 重启 Docker
sudo systemctl restart docker

# 7. 测试：从 https://hub.docker.com/r/nvidia/cuda 寻找合适的镜像
docker run --rm --gpus all nvidia/cuda:13.3.1-base-ubuntu24.04 nvidia-smi
