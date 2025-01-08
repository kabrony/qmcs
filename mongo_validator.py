import jsonschema
from motor.motor_asyncio import AsyncIOMotorClient
from typing import Dict, Any, List, Optional
from bson import ObjectId

class MongoValidator:
    def __init__(self, uri: str, db_name: str):
        self.uri = uri
        self.db_name = db_name
        self.client = None

    async def connect(self):
        self.client = AsyncIOMotorClient(self.uri)
        # Optionally ping to confirm
        await self.client.admin.command("ping")

    async def disconnect(self):
        if self.client:
            self.client.close()

    async def validate_collections(self, expected_collections: List[str]) -> Dict[str, bool]:
        """
        Ensure that each collection in expected_collections actually exists.
        """
        db = self.client[self.db_name]
        actual_collections = await db.list_collection_names()
        return {
            coll: (coll in actual_collections)
            for coll in expected_collections
        }

    async def validate_document_schema(self, collection: str, schema: dict) -> Dict[str, int]:
        """
        Validates each document in a collection against a JSON schema.
        Returns { "validation_errors": <count> }
        """
        db = self.client[self.db_name]
        coll = db[collection]
        violations = 0
        async for doc in coll.find({}):
            try:
                jsonschema.validate(instance=doc, schema=schema)
            except jsonschema.ValidationError:
                violations += 1
        return {"validation_errors": violations}

    async def find_document_by_id(self, collection: str, doc_id: str) -> Optional[dict]:
        """
        Example retrieval by _id.
        """
        db = self.client[self.db_name]
        coll = db[collection]
        return await coll.find_one({"_id": ObjectId(doc_id)})
