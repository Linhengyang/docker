# 1. systemd下，docker服务需要的配置文件都在 /etc/systemd/system/docker.service.d
# 其中 代理相关的配置写在 /etc/systemd/system/docker.service.d/proxy.conf 文件里
DOCKER_SERVICE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_PROXY_CONF="${DOCKER_SERVICE_DIR}/proxy.conf"


# 2. 获取最新代理环境变量

# 2.1 获取 Windows 主机 IP (通过 WSL e的 DNS 服务器地址)
export host_ip=$(ip route | grep default | awk '{print $3}')

# 2.2 设置代理环境变量
export HTTP_PROXY="http://${host_ip}:7897"
export HTTPS_PROXY="http://${host_ip}:7897"
# export ALL_PROXY="socks5://${host_ip}:7897"
export NO_PROXY="localhost,127.0.0.1,*.local,169.254.0.0/16,172.16.0.0/12"

# 3. 该函数将代理环境变量 HTTP_PROXY/HTTPS_PROXY/NO_PROXY 写入 docker服务的代理配置文件 DOCKER_PROXY_CONF
write_docker_proxy_conf() {
  if [[ -z "${HTTP_PROXY:-}" || -z "${HTTPS_PROXY:-}" ]]; then
    log "HTTP_PROXY / HTTPS_PROXY are not set. Skip writing Docker proxy config."
    return 1
  fi
  sudo mkdir -p "$DOCKER_SERVICE_DIR"
  sudo tee "$DOCKER_PROXY_CONF" >/dev/null <<EOF
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
Environment="HTTPS_PROXY=${HTTPS_PROXY}"
Environment="NO_PROXY=${NO_PROXY:-}"
Environment="http_proxy=${HTTP_PROXY}"
Environment="https_proxy=${HTTPS_PROXY}"
Environment="no_proxy=${NO_PROXY:-}"
EOF
  echo "Docker proxy config written to: $DOCKER_PROXY_CONF"
}

# 4. 执行 DOCKER_PROXY_CONF 注入，并让 systemd 重新读取服务配置(也就是让 DOCKER_PROXY_CONF 起效)
write_docker_proxy_conf
sudo systemctl daemon-reload

# 5. 如果 docker服务正在执行, 那么为了让 代理配置(DOCKER_PROXY_CONF)起效，要重启 docker服务。如果 docker服务本就没有运行, 那么启动后代理配置就会生效
if systemctl is-active --quiet docker.service; then
  echo "Restarting Docker to apply proxy config..."
  sudo systemctl restart docker.service
else
  echo "Docker is not running. Proxy config will apply next start."
fi

# 6. 可以停止 docker服务
sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null || true

# 7. 然后再启动 docker服务. 顺带检测是否启动成功
sudo systemctl start containerd.service docker.service
if systemctl is-active --quiet docker.service; then
  echo "Docker is running."
else
  echo "Docker failed to start." >&2
  sudo systemctl status docker.service --no-pager || true
  exit 1
fi

# 8. 打印 docker服务当前状态。若 proxy.conf 起效，会看到绿色相关标识。或者可以直接打印 Environment环境变量
sudo systemctl status containerd.service docker.service --no-pager || true
sudo systemctl show docker --property=Environment

# 9. 关闭/打开 docker服务的自动开启
sudo systemctl disable docker.service docker.socket containerd.service 2>/dev/null || true
sudo systemctl enable docker.service docker.socket containerd.service 2>/dev/null || true



# 到目前为止，如果要执行 docker 命令，比如 docker run / docker ps 等，都需要 sudo
# 10. 把用户加入到组 docker，从而省去 sudo。如果是第一次执行，那么需要关闭 wsl 后重新登陆一次
sudo usermod -aG docker "$USER"
