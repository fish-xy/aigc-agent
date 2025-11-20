from agent.base_agent import BaseAgent
from agent.prompts import AGE_CLASSIFICATION_PROMPT_V3

def test_invoke_returns_last_message_content():
    """集成测试 BaseAgent.invoke，实际调用 LLM/Agent"""
    agent = BaseAgent()  # 使用默认 config.ini 初始化

    user_input = "请简单自我介绍一下，你是谁？用一句话回答。"
    result = agent.invoke(user_input)

    # 只做非常宽松的断言，避免对具体模型输出有强依赖
    assert isinstance(result, str)
    assert result.strip() != ""


def test_run_with_image_calls_llm_and_returns_content():
    """集成测试 BaseAgent.run_with_image，实际调用多模态 LLM"""
    agent = BaseAgent(config_path = '../config.ini', system_prompt=AGE_CLASSIFICATION_PROMPT_V3)  # 使用默认 config.ini 初始化

    # 这里使用一个公开示例图像地址，你也可以换成自己可访问的 URL
    image_url = "https://img2.baidu.com/it/u=2331188438,1468638699&fm=253&app=138&f=JPEG?w=800&h=1201"
    text_prompt = "分析图片"

    result = agent.run_with_image(image_url, text_prompt)

    assert isinstance(result, str)
    assert result.strip() != ""


def test_classify_age_simple():
    """简单的 classify_age 函数测试"""
    from api.api_server import classify_age, ImageRequest  # 替换为实际模块名

    # 创建测试请求
    request = ImageRequest(
        image_url="https://i-blog.csdnimg.cn/img_convert/13c98171504f082fc789b214a7d6e75e.png"
    )

    # 直接调用函数
    result = classify_age(request)

    # 简单验证结果
    print(f"分类结果: {result.result}")
    print(f"原始响应: {result.raw_response['content']}")

    # 基本断言
    assert result.result in ["Child", "Adult", "Both", "Unclear"]
    assert len(result.result) > 0


if __name__ == "__main__":
    test_classify_age_simple()
