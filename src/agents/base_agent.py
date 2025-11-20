#!/usr/bin/env python3
"""
基础 LLM Agent，支持多模态推理和工具调用
"""
import configparser
import os
from typing import Dict, Any, List, Optional

from langchain.agents import create_agent
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import BaseTool
from langchain_openai import ChatOpenAI


class BaseAgent:
    """基础LLM Agent类，支持多模态图像处理和可配置工具"""

    def __init__(
            self,
            config_path: str = "config.ini",
            system_prompt: Optional[str] = None,
            tools: Optional[List[BaseTool]] = None
    ):
        """初始化Agent

        Args:
            config_path: 配置文件路径
            system_prompt: 系统提示词，用于多模态任务
            tools: 工具列表
        """
        self.tools = tools
        self.config = self._load_config(config_path)
        self.llm = self._initialize_llm()
        self.system_prompt = system_prompt
        self.agent = self._create_agent()

    def _load_config(self, config_path: str) -> configparser.ConfigParser:
        """加载配置文件"""
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"配置文件 {config_path} 不存在")

        config = configparser.ConfigParser()
        config.read(config_path, encoding='utf-8')
        return config

    def _initialize_llm(self) -> ChatOpenAI:
        """初始化LLM模型"""
        try:
            llm_config = self.config['llm']
            ray_config = self.config['ray']

            llm = ChatOpenAI(
                model=llm_config.get('model', 'gpt-3.5-turbo'),
                temperature=float(llm_config.get('temperature', '0.7')),
                max_tokens=int(llm_config.get('max_tokens', '2000')),
                base_url=ray_config.get('base_url', 'http://localhost:8000/v1'),
                api_key=ray_config.get('api_key', 'your-ray-api-key'),
                streaming=False
            )

            print(f"LLM初始化成功: {llm_config.get('model')}")
            return llm

        except KeyError as e:
            raise KeyError(f"配置文件中缺少必要的配置项: {e}")

    def _create_agent(self):
        if self.system_prompt:
            system_message = self.system_prompt
        else:
            # 根据可用工具动态生成系统提示词
            tool_descriptions = "\n".join([f"- {tool.name}: {tool.description}" for tool in self.tools])
            system_message = f"""你是一个有用的AI助手。你可以使用以下工具帮助用户：
{tool_descriptions}

请根据用户需求选择合适的工具，并以友好、专业的方式回应用户。"""

        agent = create_agent(
            model=self.llm,
            tools=self.tools,
            system_prompt=system_message
        )

        return agent

    def invoke(self, message: str) -> str:
        """调用Agent处理文本消息

        Args:
            message: 用户输入的消息

        Returns:
            Agent的回复
        """
        try:
            response = self.agent.invoke({
                "messages": [{"role": "user", "content": message}]
            })

            # 从响应中提取最后一条消息内容
            if (response and "messages" in response and
                    len(response["messages"]) > 0):
                last_message = response["messages"][-1]
                return last_message.content
            else:
                return "未收到有效回复"

        except Exception as e:
            return f"处理请求时出错: {str(e)}"

    def run_with_image(self, image_url: str, text_prompt: str) -> str:
        """处理包含图像的多模态请求

        Args:
            image_url: 图像URL
            text_prompt: 文本提示

        Returns:
            LLM的回复
        """
        try:
            # 创建多模态消息
            message = HumanMessage(content=[
                {"type": "text", "text": text_prompt},
                {"type": "image_url", "image_url": {"url": image_url}},
            ])

            # 直接使用LLM处理多模态输入
            if self.system_prompt:
                messages = [
                    SystemMessage(content=self.system_prompt),
                    message
                ]
            else:
                messages = [message]

            response = self.llm.invoke(messages)
            return response.content

        except Exception as e:
            return f"处理图像请求时出错: {str(e)}"

    def stream_invoke(self, message: str):
        """流式调用Agent（用于需要实时显示的场景）"""
        try:
            response = self.agent.stream({
                "messages": [{"role": "user", "content": message}]
            })

            for chunk in response:
                if "messages" in chunk and len(chunk["messages"]) > 0:
                    last_chunk = chunk["messages"][-1]
                    if hasattr(last_chunk, 'content') and last_chunk.content:
                        yield last_chunk.content

        except Exception as e:
            yield f"流式处理时出错: {str(e)}"
