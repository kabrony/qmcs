from typing import Dict, Any, Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import (
    DuplicateKeyError,
    ConnectionFailure,
    ServerSelectionTimeoutError
)
from tenacity import (
    AsyncRetrying,
    stop_after_attempt,
    wait_exponential,
    CircuitBreaker
)
from bson import ObjectId
import structlog

class VectorMetadata(BaseModel):
    """Enhanced metadata with validation"""
    timestamp: datetime
    source: str
    status: str = Field(default="active")
    version: str = Field(default="1.0")
    tags: List[str] = Field(default_factory=list)
    correlation_id: Optional[str] = None

class MongoConfig(BaseModel):
    """MongoDB configuration model"""
    uri: str = Field(default="mongodb://qmcs-mongo:27017")
    db_name: str = Field(default="memory_store")
    max_retries: int = Field(default=3)
    timeout_ms: int = Field(default=5000)
    circuit_breaker_failures: int = Field(default=5)
    circuit_breaker_reset_timeout: int = Field(default=60)

class EnhancedMongoStore:
    """Enhanced MongoDB store with circuit breaker and bulk operations"""

    def __init__(self, config: Optional[MongoConfig] = None):
        self.config = config or MongoConfig()
        self.logger = structlog.get_logger()
        self.client = None
        self.db = None
        self.ready = False
        # Circuit breaker for handling repeated failures
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=self.config.circuit_breaker_failures,
            recovery_timeout=self.config.circuit_breaker_reset_timeout
        )

    async def connect(self) -> None:
        """Explicit connection initialization with retry + exponential backoff."""
        try:
            async for attempt in AsyncRetrying(
                stop=stop_after_attempt(self.config.max_retries),
                wait=wait_exponential(multiplier=1, min=4, max=10)
            ):
                with attempt:
                    self.client = AsyncIOMotorClient(
                        self.config.uri,
                        serverSelectionTimeoutMS=self.config.timeout_ms
                    )
                    # Verify DB connectivity
                    await self.client.admin.command('ping')
                    self.db = self.client[self.config.db_name]
                    self.ready = True
                    self.logger.info("mongodb.connection.success")
        except Exception as e:
            self.logger.error("mongodb.connection.failed", error=str(e))
            raise

    async def disconnect(self) -> None:
        """Clean disconnection from MongoDB."""
        if self.client:
            self.client.close()
            self.client = None
            self.db = None
            self.ready = False
            self.logger.info("mongodb.connection.closed")

    async def store_vector(
        self,
        collection: str,
        vector: Dict[str, Any],
        correlation_id: Optional[str] = None
    ) -> str:
        """
        Store single vector with circuit breaker protection.
        Raises ConnectionError if not connected; raises if insertion fails.
        """
        if not self.ready:
            raise ConnectionError("MongoDB connection not ready")

        try:
            async with self.circuit_breaker:
                # Prepare metadata
                metadata = VectorMetadata(
                    timestamp=datetime.utcnow(),
                    source=collection,
                    correlation_id=correlation_id
                )

                document = {
                    "vector": vector,
                    "metadata": metadata.dict(),
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }

                result = await self.db[collection].insert_one(document)
                self.logger.info(
                    "mongodb.vector.stored",
                    collection=collection,
                    vector_id=str(result.inserted_id),
                    correlation_id=correlation_id
                )
                return str(result.inserted_id)

        except DuplicateKeyError as e:
            self.logger.warning(
                "mongodb.vector.duplicate",
                error=str(e),
                collection=collection,
                correlation_id=correlation_id
            )
            raise
        except Exception as e:
            self.logger.error(
                "mongodb.vector.store_failed",
                error=str(e),
                collection=collection,
                correlation_id=correlation_id
            )
            raise

    async def store_vectors(
        self,
        collection: str,
        vectors: List[Dict[str, Any]],
        correlation_id: Optional[str] = None
    ) -> List[str]:
        """
        Bulk vector storage operation with circuit breaker.
        Returns list of inserted IDs.
        """
        if not self.ready:
            raise ConnectionError("MongoDB connection not ready")

        try:
            async with self.circuit_breaker:
                documents = []
                for vector in vectors:
                    metadata = VectorMetadata(
                        timestamp=datetime.utcnow(),
                        source=collection,
                        correlation_id=correlation_id
                    )
                    documents.append({
                        "vector": vector,
                        "metadata": metadata.dict(),
                        "created_at": datetime.utcnow(),
                        "updated_at": datetime.utcnow()
                    })

                result = await self.db[collection].insert_many(documents)
                self.logger.info(
                    "mongodb.vectors.bulk_stored",
                    collection=collection,
                    count=len(vectors),
                    correlation_id=correlation_id
                )
                return [str(id_) for id_ in result.inserted_ids]

        except Exception as e:
            self.logger.error(
                "mongodb.vectors.bulk_store_failed",
                error=str(e),
                collection=collection,
                correlation_id=correlation_id
            )
            raise

    async def get_vector(
        self,
        collection: str,
        vector_id: str,
        correlation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Retrieve vector by its ObjectId string."""
        try:
            async with self.circuit_breaker:
                result = await self.db[collection].find_one(
                    {"_id": ObjectId(vector_id)}
                )
                self.logger.info(
                    "mongodb.vector.retrieved",
                    collection=collection,
                    vector_id=vector_id,
                    correlation_id=correlation_id
                )
                return result
        except Exception as e:
            self.logger.error(
                "mongodb.vector.retrieve_failed",
                error=str(e),
                collection=collection,
                vector_id=vector_id,
                correlation_id=correlation_id
            )
            return None

    async def health_check(self) -> Dict[str, Any]:
        """
        Comprehensive health check:
        - Ping the MongoDB server
        - Return circuit breaker status
        """
        try:
            if self.client:
                await self.client.admin.command('ping')
                return {
                    "status": "healthy",
                    "ready": self.ready,
                    "circuit_breaker": {
                        "state": "closed" if self.circuit_breaker.is_closed() else "open",
                        "failure_count": self.circuit_breaker.failure_count
                    }
                }
        except Exception as e:
            return {
                "status": "unhealthy",
                "ready": self.ready,
                "error": str(e),
                "circuit_breaker": {
                    "state": "open",
                    "failure_count": self.circuit_breaker.failure_count
                }
            }
