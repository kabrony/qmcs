import os
import asyncio
import traceback

try:
    import motor.motor_asyncio
except ImportError:
    print("Error: 'motor' is not installed in this environment. Please run 'pip install motor' and try again.")
    raise

async def test_mongo_connection():
    """
    Attempt to connect to a MongoDB cluster (e.g. DigitalOcean) and issue a simple 'ping' command.
    """
    mongo_uri = os.getenv("MONGO_DETAILS", "")
    
    if not mongo_uri:
        print("Error: MONGO_DETAILS environment variable is not set.")
        return

    # Provide a 60-second timeout to allow for slow connections
    client = motor.motor_asyncio.AsyncIOMotorClient(
        mongo_uri,
        serverSelectionTimeoutMS=60000  # 60 seconds
    )

    try:
        print("Connecting to MongoDB. This may take up to 60 seconds...")
        # 'ping' is a simple admin command to verify connectivity
        await client.admin.command("ping")
        print("SUCCESS: Connected to MongoDB!")
    except Exception as ex:
        print(f"FAILED: Could not connect to MongoDB. Error: {ex}")
        traceback.print_exc()
    finally:
        client.close()

def main():
    asyncio.run(test_mongo_connection())

if __name__ == "__main__":
    main()
