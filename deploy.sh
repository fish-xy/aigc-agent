#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统是否为 Debian
check_os() {
    if [[ -f /etc/debian_version ]]; then
        log_info "检测到 Debian 系统，版本: $(cat /etc/debian_version)"
        return 0
    else
        log_error "此脚本仅支持 Debian 系统"
        exit 1
    fi
}

# 检查并安装 Docker
install_docker() {
    log_info "检查 Docker 是否已安装..."

    if command -v docker &> /dev/null; then
        log_info "Docker 已安装，版本: $(docker --version)"
        return 0
    fi

    log_warn "Docker 未安装，开始安装..."

    # 更新包索引
    sudo apt-get update

    # 安装必要的依赖
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # 添加 Docker 官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 添加 Docker 仓库
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # 启动 Docker 服务
    sudo systemctl start docker
    sudo systemctl enable docker

    # 将当前用户添加到 docker 组（避免每次使用 sudo）
    sudo usermod -aG docker $USER

    log_info "Docker 安装完成"
    log_warn "请注意：需要重新登录或执行 'newgrp docker' 才能使组权限生效"
}

# 登录 Docker Hub
docker_login() {
    log_info "登录 Docker Hub..."

    local username="maxxiong001"
    local password="dckr_pat_pnQARr09Bcb6bHoIlRJ0ekB2VFE"

    # 检查是否已经登录
    if docker info 2>/dev/null | grep -q "Username: $username"; then
        log_info "Docker Hub 已经登录"
        return 0
    fi

    echo "$password" | docker login --username "$username" --password-stdin

    if [ $? -eq 0 ]; then
        log_info "Docker Hub 登录成功"
        return 0
    else
        log_error "Docker Hub 登录失败"
        return 1
    fi
}

# 拉取镜像
pull_image() {
    local image_name="maxxiong001/aigc_agent_server:latest"

    log_info "拉取镜像: $image_name"

    docker pull "$image_name"

    if [ $? -eq 0 ]; then
        log_info "镜像拉取成功"
        return 0
    else
        log_error "镜像拉取失败"
        return 1
    fi
}

# 运行容器
run_container() {
    local image_name="aigc_agent_server"
    local host_port=9000
    local container_port=9000

    log_info "启动容器，映射端口: $host_port:$container_port"

    # 检查是否已有容器在运行
    local existing_container=$(docker ps -q -f ancestor="$image_name")
    if [ ! -z "$existing_container" ]; then
        log_warn "发现正在运行的容器，停止并删除..."
        docker stop "$existing_container"
        docker rm "$existing_container"
    fi

    # 检查是否有同名的已停止容器
    local stopped_container=$(docker ps -aq -f name=aigc_agent_server)
    if [ ! -z "$stopped_container" ]; then
        log_warn "发现已停止的容器，删除..."
        docker rm "$stopped_container"
    fi

    # 运行新容器
    docker run -d \
        --name aigc_agent_server \
        -p $host_port:$container_port \
        "$image_name"

    if [ $? -eq 0 ]; then
        log_info "容器启动成功"
        return 0
    else
        log_error "容器启动失败"
        return 1
    fi
}

# 检查服务状态
check_service() {
    local port=9000
    local max_attempts=30
    local attempt=1

    log_info "检查服务状态，端口: $port"

    # 安装 netcat 如果不存在
    if ! command -v nc &> /dev/null; then
        log_warn "netcat 未安装，正在安装..."
        sudo apt-get update && sudo apt-get install -y netcat
    fi

    # 安装 curl 如果不存在
    if ! command -v curl &> /dev/null; then
        log_warn "curl 未安装，正在安装..."
        sudo apt-get update && sudo apt-get install -y curl
    fi

    # 等待服务启动
    while [ $attempt -le $max_attempts ]; do
        log_info "尝试连接服务 ($attempt/$max_attempts)..."

        # 使用 curl 检查健康端点
        if curl -s --connect-timeout 10 http://localhost:$port/health > /dev/null 2>&1; then
            log_info "服务健康检查成功"

            # 获取详细的健康信息
            local health_response=$(curl -s http://localhost:$port/health)
            log_info "健康检查响应: $health_response"

            return 0
        fi

        # 使用 netcat 检查端口
        if nc -z -w 5 localhost $port 2>/dev/null; then
            log_info "端口 $port 已开放"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    log_error "服务启动超时，端口 $port 无法访问"
    return 1
}

# 显示容器日志
show_logs() {
    log_info "显示容器日志（最后20行）..."
    docker logs --tail 20 aigc_agent_server
}

# 清理资源（可选）
cleanup() {
    log_info "清理临时文件..."
    # 这里可以添加任何需要清理的临时文件
}

# 主函数
main() {
    log_info "开始在 Debian 系统上部署 AIGC Agent Server"

    # 检查操作系统
    check_os

    # 检查并安装 Docker
    install_docker

    # 登录 Docker Hub
    if ! docker_login; then
        log_error "Docker 登录失败，退出脚本"
        exit 1
    fi

    # 拉取镜像
    if ! pull_image; then
        log_error "镜像拉取失败，退出脚本"
        exit 1
    fi

    # 运行容器
    if ! run_container; then
        log_error "容器启动失败，退出脚本"
        exit 1
    fi

    # 检查服务状态
    if check_service; then
        log_info "🎉 AIGC Agent Server 部署成功！"
        log_info "服务地址: http://localhost:9000"
        log_info "健康检查: http://localhost:9000/health"
        log_info "年龄分类接口: http://localhost:9000/classify-age"
        log_info "Qwen-VL 接口: http://localhost:9000/models/qwen-vl"
    else
        log_error "❌ 服务部署失败"
        show_logs
        exit 1
    fi

    # 显示初始日志
    show_logs

    # 清理
    cleanup

    log_info "部署完成"
}

# 信号处理
trap cleanup EXIT

# 脚本执行入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi