import logging
import os
from logging.handlers import TimedRotatingFileHandler
import pytz
from datetime import datetime

# 设置时区为北京时间
beijing_tz = pytz.timezone('Asia/Shanghai')

# 自定义一个按北京时间格式化的处理器
class BeijingTimeFormatter(logging.Formatter):
    def converter(self, timestamp):
        """将时间戳转换为北京时间"""
        return datetime.fromtimestamp(timestamp, tz=beijing_tz)

    def formatTime(self, record, datefmt=None):
        """格式化记录中的时间"""
        ct_time = self.converter(record.created)
        if datefmt:
            s = ct_time.strftime(datefmt)
        else:
            t = ct_time.strftime("%Y-%m-%d %H:%M:%S")
            s = "%s,%03d" % (t, record.msecs)
        return s
    
# 指定日志格式
log_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
beijing_formatter = BeijingTimeFormatter(log_format)

# 日志文件路径
LOG_DIR = "/home/workspace/ray-serve/logs"
LOG_FILE = os.path.join(LOG_DIR, "ray_serve_logs.log")


class SerializableTimedRotatingFileHandler(logging.handlers.TimedRotatingFileHandler):
    def __getstate__(self):
        state = self.__dict__.copy()
        # 关闭文件句柄，因为它是不可序列化的
        state['stream'] = None
        return state

    def __setstate__(self, state):
        self.__dict__.update(state)
        # 在反序列化后重新打开文件句柄
        self.stream = self._open()


def create_logger(logger_name, log_file, file_log_level):
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    # 创建 TimedRotatingFileHandler
    file_handler = TimedRotatingFileHandler(
        log_file,
        when="midnight",
        interval=1,
        backupCount=7
    )
    file_handler.setLevel(file_log_level)
    file_handler.setFormatter(formatter)
    
    # 创建 StreamHandler
    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(file_log_level)
    stream_handler.setFormatter(formatter)
    
    # 添加 handler 到 logger
    logger = logging.getLogger(logger_name)
    logger.setLevel(file_log_level)
    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)
    return logger