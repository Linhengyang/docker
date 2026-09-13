# 0. 如果额外安装了 nvidia-container-toolkit，那么需要额外删除nvidia相关。如果 nvidia-ctl存在，先执行：
sudo nvidia-ctk runtime uninstall --runtime=docker || true
# 如果命令不存在，跳过即可，后面会删除 /etc/docker

# 1. 停止 docker相关服务
sudo systemctl stop docker.service docker.socket containerd.service || true
sudo systemctl disable docker.service docker.socket containerd.service || true

# 2. 卸载 Docker包

# 卸载 nvidia相关包(如果需要)
sudo apt-get purge -y \
  nvidia-container-toolkit \
  libnvidia-container1 \
  libnvidia-container-tools || true

sudo apt-get purge -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras

# 卸载 nvidia相关包(如果需要)
sudo apt-get purge -y \
  nvidia-container-toolkit \
  libnvidia-container1 \
  libnvidia-container-tools || true


# 3. 清理自动安装的依赖
sudo apt-get autoremove --purge -y

# 4. 清理 apt缓存
sudo apt-get clean

# 5. 删除 docker 数据
sudo rm -rf /var/lib/docker

# 6. 删除 containerd 数据
sudo rm -rf /var/lib/containerd

# 7. 删除 docker 配置
sudo rm -rf /etc/docker

# 8. 删除运行目录
sudo rm -rf /run/docker
sudo rm -rf /var/run/docker
sudo rm -f /run/docker.sock
sudo rm -f /var/run/docker.sock

# 9. 删除 Docker网络接口(如果存在)
sudo ip link delete docker0 2>/dev/null || true

# 10. 删除 NVIDIA Container Toolkit 残留配置目录(如果需要)
sudo rm -rf /etc/nvidia-container-runtime
sudo rm -rf /etc/nvidia-container-toolkit

# 11. 删除 systemd 里的 Docker代理配置
sudo rm -f /etc/systemd/system/docker.service.d/proxy.conf
sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
sudo rmdir /etc/systemd/system/docker.service.d 2>/dev/null || true

# 12. 删除 Docker 的apt源和key
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg

# 清理 nvidia相关 apt源和key(如果需要)
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
sudo rm -f /etc/apt/keyrings/nvidia-container-toolkit.gpg
sudo rm -f /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg

# 13. 可能有但实际应该不太会执行的，比如 docker-compose兼容、手写apt代理
sudo rm -f /usr/local/bin/docker-compose
sudo rm -f /etc/apt/apt.conf.d/95-wsl-proxy
sudo rm -f /etc/apt/apt.conf.d/99-wsl-proxy

# 14. 删除 docker 用户组
sudo groupdel docker 2>/dev/null || true

# 15. 重载 systemd
sudo systemctl daemon-reload

# 16. 检测是否有残余
# 查看是否还有 Docker 或 NVIDIA Container Toolkit 相关包：
dpkg -l | grep -Ei 'docker|containerd|nvidia-container-toolkit' || echo "没有发现相关包"

# 查看 apt 源目录：
ls -l /etc/apt/sources.list.d

# 查看 keyring 目录：
ls -l /etc/apt/keyrings 2>/dev/null || echo "/etc/apt/keyrings 不存在"
ls -l /usr/share/keyrings 2>/dev/null || echo "/usr/share/keyrings 不存在"

# 查看 Docker 目录是否还在：
ls -ld /var/lib/docker /var/lib/containerd /etc/docker 2>/dev/null || echo "Docker 主要目录已删除"
