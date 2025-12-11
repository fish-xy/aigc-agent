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
from src.core.logger_util import create_logger
from src.utils.db_operations import insert_detection_result

import os
import json
import requests
import logging
import random

# 配置日志
logger = create_logger("api_log",
                                    os.path.join("/app/logs", "llm_server_api.log"),
                                    logging.INFO)

app = FastAPI(title="LLM Server API", version="1.0.0")


class ImageRequest(BaseModel):
    """请求体：只包含图片 URL"""

    image_url: HttpUrl
    request_info: Dict[str, Any]


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
async def qwen_vl(payload: ImageRequest):
    """
    接收图片URL和请求信息，从多个域名中随机选择调用Qwen-VL服务进行年龄分类
    返回标准化的响应格式
    """
    try:
        # 定义多个Qwen-VL服务域名
        QWEN_VL_DOMAINS = [
            "llmpic01.flyingnet.org"
        ]
        logger.info(f"请求入参，request_info: {payload.request_info}, 图片URL: {payload.image_url}")

        # 随机选择一个域名
        selected_domain = random.choice(QWEN_VL_DOMAINS)
        QWEN_VL_SERVICE_URL = f"https://{selected_domain}/models/qwen3_vl_2b/predict"

        # 组装表单数据
        form_data = {
            "request_info": json.dumps(payload.request_info),
            "image_input": str(payload.image_url),
            "prompt": AGE_CLASSIFICATION_PROMPT_V3
        }

        # 设置请求头
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json"
        }

        # 调用Qwen-VL服务
        logger.debug(f"即将调用Qwen-VL服务，URL: {QWEN_VL_SERVICE_URL}, headers: {headers}, form_data: {form_data}")
        response = requests.post(
            QWEN_VL_SERVICE_URL,
            data=form_data,
            headers=headers,
            timeout=60
        )

        # 检查响应状态
        response.raise_for_status()

        # 获取并清理Qwen-VL服务的响应
        qwen_response = response.text.strip()
        logger.info(f"Qwen-VL服务返回: {qwen_response}, 请求参数: {payload}")

        # 清理响应文本，提取年龄分类结果
        # 移除所有引号和空白字符
        cleaned_text = qwen_response.strip().strip('"').strip("'").strip()
        valid_results = ["Child", "Adult", "Both", "Unclear"]

        # 如果结果不在预期中，标记为Unclear
        if cleaned_text not in valid_results:
            cleaned_result = "Unclear"
        else:
            cleaned_result = cleaned_text

        # 构建结果
        result = {
            "status": "success",
            "result": cleaned_result.lower(),
            "raw_response": qwen_response,
        }

        # 保存到数据库
        request_info = payload.request_info
        await insert_detection_result(
            uid=str(request_info.get("uid", "")),
            image_id=str(request_info.get("image_id", "")),
            models=[request_info.get("model", "")],
            status="success",
            image_url=str(payload.image_url),
            result=result,
            request_info=json.dumps(request_info)
        )

        return result

    except requests.exceptions.RequestException as e:
        logger.error(f"调用Qwen-VL服务失败，域名: {selected_domain}, 错误: {str(e)}")
        return {
            "status": "error",
            "err_message": f"调用服务失败: {str(e)}",
        }
    except Exception as e:
        logger.error(f"处理请求时发生错误: {str(e)}")
        return {
            "status": "error",
            "err_message": f"处理请求失败: {str(e)}",
        }

@app.get("/health")
def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "LLM Age Classification API"}

@app.get("/queue")
def health_check():
    """健康检查端点"""
    return {"queue_pending": [],"queue_running": []}
