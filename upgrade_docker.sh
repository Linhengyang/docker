# 1. 获取 Windows 主机 IP (通过 WSL 的 DNS 服务器地址)
export host_ip=$(ip route | grep default | awk '{print $3}')

# 2. 设置代理环境变量
export HTTP_PROXY="http://${host_ip}:7897"
export HTTPS_PROXY="http://${host_ip}:7897"
# export ALL_PROXY="socks5://${host_ip}:7897"
export NO_PROXY="localhost,127.0.0.1,*.local,169.254.0.0/16,172.16.0.0/12"

# 3. 给 sudo apt-get 配置临时代理参数 --> aptp
aptp() {
  if [ -n "${HTTP_PROXY:-}" ] && [ -n "${HTTPS_PROXY:-}" ]; then
    sudo apt \
      -o Acquire::http::Proxy="$HTTP_PROXY" \
      -o Acquire::https::Proxy="$HTTPS_PROXY" \
      "$@"
  else
    sudo apt "$@"
  fi
}

# 3. 更新 apt索引(apt源中的地址)并升级更新 docker
aptp update
aptp install --only-upgrade -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# 4. 如果 docker 本就没启动，那么执行完3. 就结束更新了。如果 docker 在运行，或者需要重启 docker，那么执行如下：
sudo systemctl stop docker.socket docker.service || true
sudo systemctl restart containerd.service || true
sudo systemctl start docker.service

# 5. 检查 docker 服务状态
sudo systemctl status docker.service --no-pager
