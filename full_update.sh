#!/bin/bash

echo "=== 开始无损更新流程 ==="
echo

echo "步骤1: 部署临时服务并切换流量"
./deploy_temp_service.sh deploy

echo
read -p "临时服务已部署，请按回车继续更新主服务..."

echo
echo "步骤2: 更新主服务"
./deploy.sh

echo
echo "步骤3: 验证主服务状态"
./deploy_temp_service.sh status

echo
read -p "是否清理临时服务并恢复配置？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "步骤4: 清理临时服务"
    ./deploy_temp_service.sh restore
fi

echo
echo "=== 更新流程完成 ==="