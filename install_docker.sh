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
    sudo apt-get \
      -o Acquire::http::Proxy="$HTTP_PROXY" \
      -o Acquire::https::Proxy="$HTTPS_PROXY" \
      "$@"
  else
    sudo apt-get "$@"
  fi
}

# 3. 更新 apt索引(apt源中的地址) 并 apt安装一些额外必须包
aptp update
aptp install -y ca-certificates curl gnupg

# 4. 确保 /etc/apt/keyrings 存在. 这个目录保存所有 GPG keys(所以叫钥匙环), 目的是保证apt从各源地址下载时做好正确的GPG-key校验(防止网址劫持)
sudo mkdir -p /etc/apt/keyrings
sudo chmod 0755 /etc/apt/keyrings

# 5. 兜底操作：删除旧 docker GPG key
sudo rm -f /etc/apt/keyrings/docker.gpg

# 6. 获取 WSL-Linux 版本名, 与其对应的Docker代号名。本质是 export DOCKER_REPO="ubuntu"; DOCKER_CODENAME="noble"
DOCKER_REPO="$(. /etc/os-release && echo "$ID")"
DOCKER_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

case "$DOCKER_REPO" in
  linuxmint|pop)
    DOCKER_REPO=ubuntu
    ;;
esac
echo "DOCKER_REPO: $DOCKER_REPO"
echo "DOCKER_CODENAME: $DOCKER_CODENAME"

# 7. 添加 Docker 官方 GPG key。GPG key 不是简单校验下载文件是否完整，而是用于验证 Docker 官方软件包和仓库元数据是否真的来自 Docker，并且没有被篡改。
# --dearmor 的作用是把 ASCII 文本格式的 GPG key 转换成 apt 更适合的二进制 .gpg 格式。
curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO}/gpg" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg


# 8. 创建 docker 的 apt源
# 在 /etc/apt/sources.list.d/docker.list 构建类似 deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable
# 即 docker.gpg.key <=> docker.source.download.address 配对
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/%s %s stable\n' \
  "$(dpkg --print-architecture)" \
  "$DOCKER_REPO" \
  "$DOCKER_CODENAME" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 9. 更新 apt索引(apt源中的地址), 并不是更新包. 更新包要用 apt install --only-upgrade <package_name>
aptp update

# 10. 最小化安装 docker-engine, 以及 buildx 和 compose
aptp install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# 11. 关闭 Docker 的开机自启
sudo systemctl disable docker.service docker.socket containerd.service 2>/dev/null || true

# 12. 停止当前 Docker 服务
sudo systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true

# 13. 检查当前 Docker 状态
sudo systemctl status containerd.service docker.service --no-pager || true