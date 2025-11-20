"""
主程序入口
"""
from src.agents import BaseAgent
from src.core.logger import setup_logger

logger = setup_logger(__name__)


def main():
    """主函数"""
    logger.info("启动 LLM Agent 服务...")
    
    # 创建 Agent 实例
    agent = BaseAgent()
    
    # 示例：运行 Agent
    print("=" * 50)
    print("LLM Agent 示例")
    print("=" * 50)
    print("输入 'quit' 或 'exit' 退出\n")
    
    while True:
        try:
            # 获取用户输入
            user_input = input("用户: ").strip()
            
            if user_input.lower() in ['quit', 'exit', '退出']:
                print("再见！")
                break
            
            if not user_input:
                continue
            
            # 运行 Agent
            response = agent.invoke(user_input)
            print(f"助手: {response}\n")
        
        except KeyboardInterrupt:
            print("\n\n再见！")
            break
        except Exception as e:
            logger.error(f"发生错误: {e}", exc_info=True)
            print(f"错误: {e}\n")


if __name__ == "__main__":
    main()

