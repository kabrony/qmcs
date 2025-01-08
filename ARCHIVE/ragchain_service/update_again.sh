#!/bin/bash

# Navigate to the project directory (assuming the script is in the root)
cd ""

# Update import for OpenAIEmbeddings in main.py
#sed -i 's/from langchain.embeddings.openai import OpenAIEmbeddings/from langchain_openai import OpenAIEmbeddings/g' ragchain_service/main.py

# Update import for Chroma in main.py
#sed -i 's/from langchain.vectorstores import Chroma/from langchain_chroma import Chroma/g' ragchain_service/main.py

# Remove langchain-community from requirements.txt
sed -i '/langchain-community/d' ragchain_service/requirements.txt

# Remove langchain from requirements.txt
sed -i '/langchain/d' ragchain_service/requirements.txt

# Update import for OpenAIEmbeddings in openai_service/main.py
sed -i 's/from langchain.embeddings.openai import OpenAIEmbeddings/from langchain_openai import OpenAIEmbeddings/g' openai_service/main.py

# Update import for Chroma in openai_service/main.py
sed -i 's/from langchain.vectorstores import Chroma/from langchain_chroma import Chroma/g' openai_service/main.py


# Add langchain-openai to requirements.txt
echo "langchain-openai" >> ragchain_service/requirements.txt

# Add langchain-chroma to requirements.txt
echo "langchain-chroma" >> ragchain_service/requirements.txt
# Rebuild the ragchain_service Docker image
docker-compose build --no-cache ragchain_service
docker-compose build --no-cache openai_service

# Restart the Docker Compose services in detached mode
docker-compose up -d

# Display the logs for the ragchain_service to verify the changes
docker logs ragchain_service
docker logs openai_service
echo "ragchain_service update script completed."
