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

# 配置变量
TEMP_PORT=9001
TEMP_CONTAINER_NAME="aigc_agent_server_temp"
TEMP_NGINX_CONF="/etc/nginx/sites-available/aigc_agent_temp"
TEMP_NGINX_ENABLED="/etc/nginx/sites-enabled/aigc_agent_temp"
MAIN_CONTAINER_NAME="aigc_agent_server"
MAIN_PORT=9000
IMAGE_NAME="maxxiong001/aigc_agent_server:latest"

# 检查并安装 Docker（复用原脚本逻辑）
install_docker_if_needed() {
    if ! command -v docker &> /dev/null; then
        log_warn "Docker 未安装，开始安装..."
        sudo apt-get update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        log_info "Docker 安装完成"
    fi
}

# 登录 Docker Hub
docker_login() {
    log_info "登录 Docker Hub..."
    local username="maxxiong001"
    local password="dckr_pat_pnQARr09Bcb6bHoIlRJ0ekB2VFE"

    echo "$password" | docker login --username "$username" --password-stdin
    if [ $? -eq 0 ]; then
        log_info "Docker Hub 登录成功"
        return 0
    else
        log_error "Docker Hub 登录失败"
        return 1
    fi
}

# 拉取最新镜像
pull_latest_image() {
    log_info "拉取最新镜像: $IMAGE_NAME"
    docker pull "$IMAGE_NAME"

    if [ $? -eq 0 ]; then
        log_info "镜像拉取成功"
        return 0
    else
        log_error "镜像拉取失败"
        return 1
    fi
}

# 部署临时服务
deploy_temp_service() {
    log_info "开始部署临时服务到端口 $TEMP_PORT..."

    # 检查是否已有临时容器
    local existing_temp_container=$(docker ps -aq -f name="$TEMP_CONTAINER_NAME")
    if [ ! -z "$existing_temp_container" ]; then
        log_warn "发现已有的临时容器，正在清理..."
        docker stop "$TEMP_CONTAINER_NAME" 2>/dev/null
        docker rm "$TEMP_CONTAINER_NAME" 2>/dev/null
    fi

    # 检查端口是否被占用
    if ss -tuln | grep -q ":$TEMP_PORT "; then
        log_error "端口 $TEMP_PORT 已被占用"
        return 1
    fi

    # 运行临时容器
    log_info "启动临时容器: $TEMP_CONTAINER_NAME 端口: $TEMP_PORT"
    docker run -d \
        --name "$TEMP_CONTAINER_NAME" \
        -p "$TEMP_PORT":9000 \
        "$IMAGE_NAME"

    if [ $? -eq 0 ]; then
        log_info "临时容器启动成功"
        return 0
    else
        log_error "临时容器启动失败"
        return 1
    fi
}

# 检查临时服务健康状态
check_temp_service_health() {
    local max_attempts=30
    local attempt=1

    log_info "检查临时服务健康状态 (端口: $TEMP_PORT)..."

    # 安装必要的工具
    if ! command -v curl &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl
    fi

    while [ $attempt -le $max_attempts ]; do
        log_info "尝试连接临时服务 ($attempt/$max_attempts)..."

        if curl -s --connect-timeout 10 "http://localhost:$TEMP_PORT/health" > /dev/null 2>&1; then
            local health_response=$(curl -s "http://localhost:$TEMP_PORT/health")
            log_info "临时服务健康检查成功: $health_response"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    log_error "临时服务启动超时"
    return 1
}

# 配置 Nginx 指向临时服务
setup_nginx_for_temp_service() {
    log_info "配置 Nginx 指向临时服务..."

    # 检查 Nginx 是否安装
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx 未安装，请先安装 Nginx"
        return 1
    fi

    # 创建临时 Nginx 配置
    log_info "创建临时 Nginx 配置文件..."
    sudo tee "$TEMP_NGINX_CONF" > /dev/null << EOF
server {
    listen 80;
    listen [::]:80;
    server_name llmagent01.flyingnet.org;

    # 临时重定向到 HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name llmagent01.flyingnet.org;

    # 使用现有的 SSL 证书
    ssl_certificate /etc/ssl/certs/netful/netful.org.pem;
    ssl_certificate_key /etc/ssl/certs/netful/netful.org.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 20M;

    # 健康检查指向临时服务
    location = /health {
        proxy_pass http://127.0.0.1:$TEMP_PORT/health;
        proxy_set_header Host \$host;
        access_log off;
    }

    # 反向代理指向临时服务
    location / {
        proxy_pass http://127.0.0.1:$TEMP_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Connection "upgrade";
        proxy_set_header Upgrade \$http_upgrade;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    # 启用临时配置
    sudo ln -sf "$TEMP_NGINX_CONF" "$TEMP_NGINX_ENABLED"

    # 测试并重载 Nginx
    if sudo nginx -t; then
        log_info "Nginx 配置测试通过，重新加载配置..."
        sudo systemctl reload nginx
        log_info "Nginx 已指向临时服务 (端口: $TEMP_PORT)"
        return 0
    else
        log_error "Nginx 配置测试失败"
        return 1
    fi
}

# 恢复 Nginx 指向主服务
restore_nginx_to_main_service() {
    log_info "恢复 Nginx 指向主服务 (端口: $MAIN_PORT)..."

    # 删除临时配置链接
    sudo rm -f "$TEMP_NGINX_ENABLED"

    # 测试并重载 Nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx
        log_info "Nginx 已恢复指向主服务 (端口: $MAIN_PORT)"
        return 0
    else
        log_error "Nginx 配置恢复失败"
        return 1
    fi
}

# 清理临时服务
cleanup_temp_service() {
    log_info "清理临时服务..."

    # 停止并删除临时容器
    if docker ps -aq -f name="$TEMP_CONTAINER_NAME" | grep -q .; then
        docker stop "$TEMP_CONTAINER_NAME" 2>/dev/null
        docker rm "$TEMP_CONTAINER_NAME" 2>/dev/null
        log_info "临时容器已清理"
    fi

    # 删除临时 Nginx 配置
    sudo rm -f "$TEMP_NGINX_CONF" 2>/dev/null
    log_info "临时服务清理完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  deploy    部署临时服务并切换 Nginx"
    echo "  restore   恢复 Nginx 到主服务并清理临时服务"
    echo "  status    显示当前服务状态"
    echo "  help      显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 deploy     # 部署临时服务"
    echo "  $0 restore    # 恢复主服务"
    echo "  $0 status     # 查看状态"
}

# 显示状态
show_status() {
    echo "=== 当前服务状态 ==="
    echo

    # 显示容器状态
    echo "容器状态:"
    echo "  主服务 ($MAIN_CONTAINER_NAME):"
    if docker ps -a --filter "name=$MAIN_CONTAINER_NAME" | grep -q "$MAIN_CONTAINER_NAME"; then
        docker ps -a --filter "name=$MAIN_CONTAINER_NAME"
    else
        echo "  - 未找到"
    fi

    echo "  临时服务 ($TEMP_CONTAINER_NAME):"
    if docker ps -a --filter "name=$TEMP_CONTAINER_NAME" | grep -q "$TEMP_CONTAINER_NAME"; then
        docker ps -a --filter "name=$TEMP_CONTAINER_NAME"
    else
        echo "  - 未找到"
    fi

    echo

    # 显示端口监听状态
    echo "端口监听状态:"
    echo "  端口 $MAIN_PORT:"
    if ss -tuln | grep -q ":$MAIN_PORT "; then
        echo "  - 正在监听"
    else
        echo "  - 未监听"
    fi

    echo "  端口 $TEMP_PORT:"
    if ss -tuln | grep -q ":$TEMP_PORT "; then
        echo "  - 正在监听"
    else
        echo "  - 未监听"
    fi

    echo

    # 显示 Nginx 配置状态
    echo "Nginx 配置:"
    if [ -L "$TEMP_NGINX_ENABLED" ]; then
        echo "  - 当前指向: 临时服务 (端口 $TEMP_PORT)"
    elif [ -L "/etc/nginx/sites-enabled/aigc_agent_https" ]; then
        echo "  - 当前指向: 主服务 (端口 $MAIN_PORT)"
    else
        echo "  - 未找到相关配置"
    fi
}

# 主流程 - 部署临时服务
deploy_temp() {
    log_info "开始部署临时服务流程..."

    # 1. 检查 Docker
    install_docker_if_needed

    # 2. 登录 Docker Hub
    if ! docker_login; then
        log_error "Docker 登录失败"
        exit 1
    fi

    # 3. 拉取最新镜像
    if ! pull_latest_image; then
        log_error "镜像拉取失败"
        exit 1
    fi

    # 4. 部署临时服务
    if ! deploy_temp_service; then
        log_error "临时服务部署失败"
        exit 1
    fi

    # 5. 检查临时服务健康
    if ! check_temp_service_health; then
        log_error "临时服务健康检查失败"
        cleanup_temp_service
        exit 1
    fi

    # 6. 配置 Nginx 指向临时服务
    if ! setup_nginx_for_temp_service; then
        log_error "Nginx 配置失败"
        cleanup_temp_service
        exit 1
    fi

    log_info "🎉 临时服务部署完成！"
    log_info "现在流量已切换到临时服务 (端口: $TEMP_PORT)"
    log_info "你可以安全地更新主服务了"
    log_info "更新完成后，请执行: $0 restore"
}

# 主流程 - 恢复主服务
restore_main() {
    log_info "开始恢复主服务流程..."

    # 1. 检查主服务是否正常运行
    log_info "检查主服务状态..."
    if curl -s --connect-timeout 10 "http://localhost:$MAIN_PORT/health" > /dev/null 2>&1; then
        log_info "主服务运行正常"
    else
        log_warn "主服务可能未运行，请确保主服务已更新并启动"
        read -p "是否继续恢复操作？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作取消"
            exit 0
        fi
    fi

    # 2. 恢复 Nginx 配置
    if ! restore_nginx_to_main_service; then
        log_error "Nginx 恢复失败"
        exit 1
    fi

    # 3. 清理临时服务
    cleanup_temp_service

    # 4. 验证恢复结果
    sleep 2
    log_info "验证恢复结果..."
    if curl -s --connect-timeout 10 "https://llmagent01.flyingnet.org/health" > /dev/null 2>&1; then
        local response=$(curl -s "https://llmagent01.flyingnet.org/health")
        log_info "服务恢复成功: $response"
        log_info "🎉 服务切换完成！"
        log_info "当前流量已切换到主服务 (端口: $MAIN_PORT)"
    else
        log_warn "HTTPS 访问失败，尝试 HTTP..."
        if curl -s --connect-timeout 10 "http://llmagent01.flyingnet.org/health" > /dev/null 2>&1; then
            log_info "HTTP 访问成功，HTTPS 可能需要证书配置"
        else
            log_error "服务验证失败，请手动检查"
        fi
    fi
}

# 主函数
main() {
    local action=${1:-help}

    case "$action" in
        deploy)
            deploy_temp
            ;;
        restore)
            restore_main
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "错误: 未知操作 '$action'"
            show_help
            exit 1
            ;;
    esac
}

# 执行入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi