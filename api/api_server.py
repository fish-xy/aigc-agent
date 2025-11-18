"""
HTTP 接口服务：

- 提供 /classify-age 接口
- 入参：JSON，字段 image_url（图片 URL）
- 功能：使用 Ray LLM（通过 OpenAI 兼容接口）+ 年龄分类系统提示词，对图片进行年龄分类
"""

from typing import Any, Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl

from agent.base_agent import BaseAgent
from agent.prompts import AGE_CLASSIFICATION_PROMPT_V3


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


@app.get("/health")
def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "LLM Age Classification API"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)