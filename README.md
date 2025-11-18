# AIGC LLM Server

基于 LangChain 的 LLM Agent 开发项目

## 项目结构

```
aigc_llm_server/
├── agent/              # Agent 相关代码
│   ├── __init__.py
│   └── base_agent.py   # 基础 Agent 类
├── utils/              # 工具函数
│   ├── __init__.py
│   └── logger.py       # 日志工具
├── examples/           # 示例代码
│   ├── __init__.py
│   └── basic_example.py
├── config.py           # 配置文件
├── main.py             # 主程序入口
├── requirements.txt    # Python 依赖
├── Dockerfile          # Docker 镜像构建文件
├── docker-compose.yml  # Docker Compose 配置
├── .dockerignore       # Docker 忽略文件
├── env.example         # 环境变量示例
└── README.md           # 项目说明
```

## 环境要求

- Python 3.8+（本地开发）
- Docker 和 Docker Compose（容器化部署）
- pip

## 安装步骤

### 方式一：本地开发

1. 克隆项目（如果适用）
```bash
git clone <repository_url>
cd aigc_llm_server
```

2. 创建虚拟环境（推荐）
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

3. 安装依赖
```bash
pip install -r requirements.txt
```

4. 配置环境变量

创建 `.env` 文件（参考 `env.example`）：
```bash
OPENAI_API_KEY=your_openai_api_key_here
LLM_MODEL=gpt-4
LLM_TEMPERATURE=0.7
LOG_LEVEL=INFO
```

### 方式二：Docker 部署

1. 构建 Docker 镜像
```bash
docker build -t aigc-llm-server .
```

2. 运行容器
```bash
# 使用 docker run
docker run -it --rm \
  --env-file .env \
  -v $(pwd)/logs:/app/logs \
  aigc-llm-server

# 或使用 docker-compose
docker-compose up
```

3. 后台运行
```bash
docker-compose up -d
```

4. 查看日志
```bash
docker-compose logs -f
```

5. 停止服务
```bash
docker-compose down
```

## 使用方法

### 基础使用

运行主程序：
```bash
python main.py
```

### 在代码中使用

```python
from agent import BaseAgent

# 创建 Agent 实例
agent = BaseAgent()

# 运行查询
response = agent.run("你好，请介绍一下自己")
print(response)
```

### 添加自定义工具

```python
from langchain_core.tools import tool
from agent import BaseAgent

# 定义工具
@tool
def calculator(expression: str) -> str:
    """计算数学表达式"""
    return str(eval(expression))

# 创建带工具的 Agent
agent = BaseAgent(tools=[calculator])

# 使用
response = agent.run("计算 123 + 456")
```

## 配置说明

在 `config.py` 或 `.env` 文件中可以配置：

- `OPENAI_API_KEY`: OpenAI API 密钥（必需）
- `ANTHROPIC_API_KEY`: Anthropic API 密钥（可选）
- `LLM_MODEL`: 使用的模型名称（默认: gpt-4）
- `LLM_TEMPERATURE`: 模型温度参数（默认: 0.7）
- `LOG_LEVEL`: 日志级别（默认: INFO）

## Docker 说明

项目包含完整的 Docker 支持：

- **Dockerfile**: 基于 Python 3.12-slim 的轻量级镜像
- **docker-compose.yml**: 便捷的容器编排配置
- **.dockerignore**: 优化构建过程，排除不必要文件

### Docker 镜像构建

```bash
# 构建镜像
docker build -t aigc-llm-server:latest .

# 查看镜像
docker images | grep aigc-llm-server
```

### 环境变量配置

在运行 Docker 容器时，可以通过以下方式传递环境变量：

1. **使用 .env 文件**（推荐）：
```bash
docker run -it --env-file .env aigc-llm-server
```

2. **使用环境变量**：
```bash
docker run -it \
  -e OPENAI_API_KEY=your_key \
  -e LLM_MODEL=gpt-4 \
  aigc-llm-server
```

3. **使用 docker-compose**：
在 `docker-compose.yml` 中配置，或使用 `.env` 文件

## 开发计划

- [x] 基础项目结构
- [x] LangChain Agent 集成
- [x] Docker 支持
- [ ] 工具集成示例
- [ ] API 服务接口
- [ ] 多 Agent 协作
- [ ] 持久化存储

## 许可证

MIT License
