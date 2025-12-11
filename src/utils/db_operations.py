import os
import logging
import json
import asyncio
import traceback
from contextlib import asynccontextmanager
import asyncpg
from src.core.logger_util import create_logger

# 日志目录
LOG_DIR = "/app/logs"

# 数据库配置
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "34.26.149.71"),
    "port": os.getenv("DB_PORT", "5432"),
    "database": os.getenv("DB_NAME", "aigc_log"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "Passwd_123456")
}

# 全局变量
_connection_pool = None
_pool_initialized = False
_initializing = False
_logger = None


def get_logger():
    """获取日志记录器"""
    global _logger
    if _logger is None:
        _logger = create_logger("database_manager",
                                os.path.join(LOG_DIR, "database_manager_logs.log"),
                                logging.INFO)
    return _logger


async def ensure_pool_initialized():
    """确保连接池已初始化"""
    global _connection_pool, _pool_initialized, _initializing

    logger = get_logger()

    if _pool_initialized:
        logger.debug("Connection pool already initialized")
        return

    if _initializing:
        logger.info("Connection pool is being initialized, waiting...")
        for i in range(50):
            await asyncio.sleep(0.1)
            if _pool_initialized:
                logger.info("Connection pool initialized by another process")
                return
        logger.warning("Timeout waiting for connection pool initialization")
        return

    _initializing = True
    logger.info("Starting connection pool initialization")

    try:
        logger.info(f"Creating connection pool with config: host={DB_CONFIG['host']}, db={DB_CONFIG['database']}")
        _connection_pool = await asyncpg.create_pool(
            min_size=1,
            max_size=10,
            **DB_CONFIG
        )
        _pool_initialized = True
        logger.info("Database connection pool initialized successfully")
    except Exception as e:
        logger.error(f"Database connection pool initialization failed: {str(e)}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        _connection_pool = None
        _pool_initialized = False
    finally:
        _initializing = False


@asynccontextmanager
async def get_connection():
    """获取数据库连接的异步上下文管理器"""
    logger = get_logger()
    logger.debug("Acquiring database connection")

    await ensure_pool_initialized()

    if _connection_pool is None or not _pool_initialized:
        logger.warning("Database connection pool not available, skipping database operation")
        yield None
        return

    conn = None
    try:
        conn = await _connection_pool.acquire()
        logger.debug("Successfully acquired database connection from pool")
        yield conn
    except Exception as e:
        logger.error(f"Error getting database connection: {str(e)}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise
    finally:
        if conn:
            await _connection_pool.release(conn)
            logger.debug("Released database connection back to pool")


async def insert_detection_result(uid: str, image_id: str, models: list, status: str, image_url: str, result: dict, request_info: str):
    """异步插入检测结果到数据库"""
    logger = get_logger()
    logger.info(f"Starting database insertion: models={models}, status={status}, image_url={image_url[:100]}...")

    try:
        async with get_connection() as conn:
            if conn is None:
                logger.warning("Skipping database insertion - no connection available")
                return None

            insert_sql = """
            INSERT INTO model_predict_record (uid, image_id, models, status, image_url, result, request_info, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
            RETURNING id
            """

            logger.debug(f"Executing SQL: {insert_sql}")
            logger.debug(
                f"With parameters: uid={uid}, image_id={image_id}, models={models}, status={status}, image_url={image_url}, result_keys={list(result.keys()) if result else 'None'}")

            record_id = await conn.fetchval(
                insert_sql,
                int(uid),
                image_id,
                models,
                status,
                image_url,
                json.dumps(result) if result else None,
                request_info
            )

            logger.info(f"Detection result saved to database with ID: {record_id}")
            return record_id

    except Exception as e:
        logger.error(f"Failed to insert detection result: {str(e)}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        logger.error(f"Insertion parameters - uid: {uid}, image_id: {image_id}, models: {models}, status: {status}, image_url: {image_url}")
        return None


async def close_connections():
    """关闭所有数据库连接"""
    logger = get_logger()
    logger.info("Closing database connections")

    global _connection_pool, _pool_initialized

    if _connection_pool:
        try:
            await _connection_pool.close()
            _pool_initialized = False
            logger.info("Database connections closed successfully")
        except Exception as e:
            logger.error(f"Error closing database connections: {str(e)}")
            logger.error(f"Exception type: {type(e).__name__}")
            logger.error(f"Full traceback: {traceback.format_exc()}")