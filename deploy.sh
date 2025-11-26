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
    local container_name="aigc_agent_server"

    log_info "检查本地容器和镜像状态..."

    # 检查是否有正在运行的容器
    local running_container=$(docker ps -q -f name="$container_name")
    if [ ! -z "$running_container" ]; then
        log_warn "发现正在运行的容器: $running_container，正在停止..."
        docker stop "$running_container"
        if [ $? -eq 0 ]; then
            log_info "容器停止成功"
        else
            log_error "容器停止失败"
            return 1
        fi
    fi

    # 检查是否有已停止的容器
    local stopped_container=$(docker ps -aq -f name="$container_name")
    if [ ! -z "$stopped_container" ]; then
        log_warn "发现已停止的容器: $stopped_container，正在删除..."
        docker rm "$stopped_container"
        if [ $? -eq 0 ]; then
            log_info "容器删除成功"
        else
            log_error "容器删除失败"
            return 1
        fi
    fi

    # 检查本地是否存在同名镜像
    local existing_image=$(docker images -q "$image_name")
    if [ ! -z "$existing_image" ]; then
        log_warn "发现本地镜像: $existing_image，正在删除..."
        docker rmi "$image_name"
        if [ $? -eq 0 ]; then
            log_info "本地镜像删除成功"
        else
            log_error "本地镜像删除失败"
            # 如果删除失败，尝试强制删除
            log_warn "尝试强制删除镜像..."
            docker rmi -f "$image_name"
            if [ $? -eq 0 ]; then
                log_info "镜像强制删除成功"
            else
                log_error "镜像强制删除失败，可能仍有容器依赖"
                return 1
            fi
        fi
    fi

    log_info "开始拉取最新镜像: $image_name"

    # 拉取新镜像
    docker pull "$image_name"

    if [ $? -eq 0 ]; then
        log_info "镜像拉取成功"

        # 验证镜像信息
        local new_image_id=$(docker images -q "$image_name")
        log_info "新镜像ID: $new_image_id"

        # 显示镜像详情
        docker images | grep "$(echo $image_name | cut -d: -f1)"

        return 0
    else
        log_error "镜像拉取失败"
        return 1
    fi
}

# 运行容器
run_container() {
    local image_name="maxxiong001/aigc_agent_server:latest"
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

# 安装和配置 Nginx 反向代理
setup_nginx_proxy() {
    local app_port=9000
    local nginx_conf="/etc/nginx/sites-available/aigc_agent"
    local nginx_enabled="/etc/nginx/sites-enabled/aigc_agent"

    log_info "检查 Nginx 是否已安装..."

    # 检查是否已安装 Nginx
    if ! command -v nginx &> /dev/null; then
        log_warn "Nginx 未安装，开始安装..."
        sudo apt-get update
        sudo apt-get install -y nginx

        if [ $? -eq 0 ]; then
            log_info "Nginx 安装成功"
        else
            log_error "Nginx 安装失败"
            return 1
        fi
    else
        log_info "Nginx 已安装，版本: $(nginx -v 2>&1)"
    fi

    # 创建 Nginx 配置文件
    log_info "创建 Nginx 配置文件..."

    sudo tee "$nginx_conf" > /dev/null << EOF
server {
    listen 80;
    server_name http://llmagent01.flyingnet.org;

    # 反向代理配置
    location / {
        proxy_pass http://127.0.0.1:$app_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查端点
    location /health {
        proxy_pass http://127.0.0.1:$app_port/health;
        proxy_set_header Host \$host;
        access_log off;
    }

    # 静态文件缓存（如果有的话）
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    if [ $? -eq 0 ]; then
        log_info "Nginx 配置文件创建成功: $nginx_conf"
    else
        log_error "Nginx 配置文件创建失败"
        return 1
    fi

    # 启用站点配置
    log_info "启用 Nginx 站点配置..."

    # 删除默认配置（如果存在）
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        sudo rm -f "/etc/nginx/sites-enabled/default"
        log_info "已删除默认 Nginx 站点配置"
    fi

    # 创建符号链接启用配置
    if [ ! -L "$nginx_enabled" ]; then
        sudo ln -sf "$nginx_conf" "$nginx_enabled"
        log_info "Nginx 站点配置已启用"
    fi

    # 测试 Nginx 配置
    log_info "测试 Nginx 配置..."
    if sudo nginx -t; then
        log_info "Nginx 配置测试通过"
    else
        log_error "Nginx 配置测试失败"
        return 1
    fi

    # 启动或重启 Nginx
    log_info "启动/重启 Nginx 服务..."

    if sudo systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx
        log_info "Nginx 服务已重新加载"
    else
        sudo systemctl start nginx
        sudo systemctl enable nginx
        log_info "Nginx 服务已启动并设置开机自启"
    fi

    # 检查 Nginx 服务状态
    if sudo systemctl is-active --quiet nginx; then
        log_info "Nginx 服务运行正常"

        # 检查防火墙状态（如果启用）
        if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
            log_warn "检测到 UFW 防火墙已启用，确保端口 80 已开放"
            if ! sudo ufw status | grep -q "80.*ALLOW"; then
                log_info "开放端口 80"
                sudo ufw allow 80/tcp
            fi
        fi

        return 0
    else
        log_error "Nginx 服务启动失败"
        return 1
    fi
}

# 检查 Nginx 代理状态
check_nginx_proxy() {
    local max_attempts=10
    local attempt=1

    log_info "检查 Nginx 反向代理状态..."

    while [ $attempt -le $max_attempts ]; do
        log_info "测试代理连接 ($attempt/$max_attempts)..."

        if curl -s --connect-timeout 10 http://localhost/health > /dev/null 2>&1; then
            local health_response=$(curl -s http://localhost/health)
            log_info "Nginx 代理健康检查成功: $health_response"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    log_error "Nginx 代理连接超时"
    return 1
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

        # 设置 Nginx 反向代理
        log_info "开始设置 Nginx 反向代理..."
        if setup_nginx_proxy; then
            if check_nginx_proxy; then
                log_info "🎉 Nginx 反向代理配置成功！"
                log_info "现在可以通过以下地址访问服务："
                log_info "HTTP 地址: http://localhost"
                log_info "健康检查: http://localhost/health"
                log_info "原始端口仍然可用: http://localhost:9000"
            else
                log_warn "Nginx 代理检查失败，但原始服务仍在运行"
            fi
        else
            log_warn "Nginx 配置失败，但原始服务仍在端口 9000 运行"
        fi
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