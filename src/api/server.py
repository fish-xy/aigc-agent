"""
HTTP 接口服务：

- 提供 /classify-age 接口
- 入参：JSON，字段 image_url（图片 URL）
- 功能：使用 Ray LLM（通过 OpenAI 兼容接口）+ 年龄分类系统提示词，对图片进行年龄分类
"""

from typing import Any, Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl

from src.agents.base_agent import BaseAgent
from  src.prompts.age_classification import AGE_CLASSIFICATION_PROMPT_V3

import os
import json
import requests
import logging

# 配置日志
logger = logging.getLogger(__name__)

app = FastAPI(title="LLM Age Classification API", version="1.0.0")


class ImageRequest(BaseModel):
    """请求体：只包含图片 URL"""

    image_url: HttpUrl


class AgeClassificationResponse(BaseModel):
    """返回体：原始模型输出文本（通常会是 Child / Adult / Both / Unclear）"""

    result: str
    raw_response: Dict[str, Any]


# 使用 BaseAgent 来处理年龄分类任务
# 传入年龄分类的系统提示词，BaseAgent 会自动根据配置选择 Ray LLM 或 OpenAI
age_classification_agent = BaseAgent(
    config_path=os.getenv('CONFIG_PATH', '/app/config.ini'),
    system_prompt=AGE_CLASSIFICATION_PROMPT_V3,
)


@app.post("/classify-age", response_model=AgeClassificationResponse)
def classify_age(payload: ImageRequest) -> AgeClassificationResponse:
    """
    根据图片 URL 调用 Ray LLM，对人物年龄进行分类。

    使用 BaseAgent 的 run_with_image 方法来处理多模态输入。
    """
    try:
        image_url = str(payload.image_url)

        text_prompt = "Classify the age of the person in this image."
        result_text = age_classification_agent.run_with_image(
            image_url=image_url,
            text_prompt=text_prompt,
        )

        # 清理响应文本，确保只包含分类结果
        cleaned_result = result_text.strip()
        valid_results = ["Child", "Adult", "Both", "Unclear"]

        # 如果结果不在预期中，标记为Unclear
        if cleaned_result not in valid_results:
            cleaned_result = "Unclear"

        # 构建返回响应
        raw_response: Dict[str, Any] = {
            "content": result_text,
            "cleaned_content": cleaned_result
        }

        return AgeClassificationResponse(
            result=cleaned_result,
            raw_response=raw_response
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"处理请求时出错: {str(e)}")


@app.post("/models/qwen-vl")
def qwen_vl(payload: ImageRequest):
    """
    接收图片URL，调用Qwen-VL服务进行年龄分类
    直接返回Qwen-VL服务的响应
    """
    try:
        # Qwen-VL服务的URL - 请根据实际情况修改
        QWEN_VL_SERVICE_URL = "https://t6ohp9y6v15xhp-8000.proxy.runpod.net//models/qwen3_vl_2b/predict"

        # 准备请求参数
        request_info = json.dumps({
            "task": "age_classification",
            "model": "qwen-vl"
        })

        # 组装表单数据
        form_data = {
            "request_info": request_info,
            "image_input": str(payload.image_url),  # 将HttpUrl转换为字符串
            "prompt": AGE_CLASSIFICATION_PROMPT_V3
        }

        # 设置请求头
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json"
        }

        # 调用Qwen-VL服务
        logger.info(f"调用Qwen-VL服务，图片URL: {payload.image_url}")
        response = requests.post(
            QWEN_VL_SERVICE_URL,
            data=form_data,
            headers=headers,
            timeout=60  # 设置超时时间
        )

        # 检查响应状态
        response.raise_for_status()

        # 直接返回Qwen-VL服务的响应
        qwen_response = response.text.strip()
        logger.info(f"Qwen-VL服务返回: {qwen_response}")

        return qwen_response

    except requests.exceptions.RequestException as e:
        logger.error(f"调用Qwen-VL服务失败: {str(e)}")
        # 返回错误信息
        return f"Error: {str(e)}"
    except Exception as e:
        logger.error(f"处理请求时发生错误: {str(e)}")
        # 返回错误信息
        return f"Error: {str(e)}"


@app.get("/health")
def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "LLM Age Classification API"}
