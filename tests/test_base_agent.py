from agent.base_agent import BaseAgent


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
    agent = BaseAgent()  # 使用默认 config.ini 初始化

    # 这里使用一个公开示例图像地址，你也可以换成自己可访问的 URL
    image_url = "https://picsum.photos/200"
    text_prompt = "请用一句话描述这张图片的大致内容。"

    result = agent.run_with_image(image_url, text_prompt)

    assert isinstance(result, str)
    assert result.strip() != ""


if __name__ == '__main__':
    test_invoke_returns_last_message_content()
    test_run_with_image_calls_llm_and_returns_content()
