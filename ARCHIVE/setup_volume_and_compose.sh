#!/usr/bin/env bash
set -e

################################################################################
# setup_volume_and_compose.sh
#
# This script unmounts volumes if they are already mounted, then re-mounts them
# at /mnt/my_volume and /mnt/volume_sfo3_01. It also updates /etc/fstab so the
# volumes remount after reboot. Finally, it creates a docker-compose.yml with
# memory limits on local_mongo, solana_agents, ragchain_service, and quant_service.
#
# USAGE:
#   chmod +x setup_volume_and_compose.sh
#   ./setup_volume_and_compose.sh
#
#   Then run your usual docker-compose commands:
#     docker compose build
#     docker compose up -d
################################################################################

### VOLUME PATHS (change if needed) ############################################
VOL1_DISK="/dev/disk/by-id/scsi-0DO_Volume_my-volume"
VOL2_DISK="/dev/disk/by-id/scsi-0DO_Volume_volume-sfo3-01"

VOL1_MOUNT="/mnt/my_volume"
VOL2_MOUNT="/mnt/volume_sfo3_01"

### 1) UNMOUNT ANY EXISTING MOUNTS IF MOUNT POINT BUSY OR ALREADY MOUNTED ######
echo "[INFO] 1/6: Checking if volumes are already mounted..."
if mountpoint -q "$VOL1_MOUNT"; then
  echo "[WARN] $VOL1_MOUNT is mounted, unmounting..."
  sudo umount "$VOL1_MOUNT" || true
fi

if mountpoint -q "$VOL2_MOUNT"; then
  echo "[WARN] $VOL2_MOUNT is mounted, unmounting..."
  sudo umount "$VOL2_MOUNT" || true
fi

### 2) CREATE MOUNT POINT DIRECTORIES ##########################################
echo "[INFO] 2/6: Creating directories $VOL1_MOUNT and $VOL2_MOUNT (if needed)..."
sudo mkdir -p "$VOL1_MOUNT"
sudo mkdir -p "$VOL2_MOUNT"

### 3) MOUNT THE VOLUMES #######################################################
echo "[INFO] 3/6: Mounting volumes now..."
echo "[INFO] Mounting $VOL1_DISK -> $VOL1_MOUNT"
sudo mount -o discard,defaults,noatime "$VOL1_DISK" "$VOL1_MOUNT"

echo "[INFO] Mounting $VOL2_DISK -> $VOL2_MOUNT"
sudo mount -o discard,defaults,noatime "$VOL2_DISK" "$VOL2_MOUNT"

### 4) UPDATE /etc/fstab FOR PERSISTENCE #######################################
echo "[INFO] 4/6: Updating /etc/fstab so volumes mount on reboot..."

# Remove old duplicates, if any
sudo sed -i "\|$VOL1_DISK|d" /etc/fstab
sudo sed -i "\|$VOL2_DISK|d" /etc/fstab

# Now append fresh lines
echo "$VOL1_DISK $VOL1_MOUNT ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab
echo "$VOL2_DISK $VOL2_MOUNT ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab

### 5) CREATE OR OVERWRITE DOCKER-COMPOSE.YML ##################################
echo "[INFO] 5/6: Writing docker-compose.yml with memory limits..."

cat << 'EOF' > docker-compose.yml
version: '3.8'
services:

  local_mongo:
    image: 'mongo:6.0'
    container_name: local_mongo
    mem_limit: 1g
    ports:
      - "27017:27017"
    volumes:
      - my_mongo_data:/data/db
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.runCommand({ ping: 1 })"]
      interval: 10s
      timeout: 5s
      retries: 5

  solana_agents:
    build: ./solana_agents
    container_name: solana_agents
    mem_limit: 512m
    ports:
      - "4000:4000"
    environment:
      PORT: 4000
      SOLANA_RPC_URL: ${SOLANA_RPC_URL}
      SOLANA_PRIVATE_KEY: ${SOLANA_PRIVATE_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      TAVILY_API_KEY: ${TAVILY_API_KEY}
      RAGCHAIN_URL: http://ragchain_service:5000
      QUANT_URL: http://quant_service:7000
    depends_on:
      - ragchain_service
      - quant_service
      - local_mongo
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  ragchain_service:
    build: ./ragchain_service
    container_name: ragchain_service
    mem_limit: 512m
    ports:
      - "5000:5000"
    environment:
      MONGO_DETAILS: ${MONGO_DETAILS}
    depends_on:
      - local_mongo
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  quant_service:
    build: ./quant_service
    container_name: quant_service
    mem_limit: 512m
    ports:
      - "7000:7000"
    environment:
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      MONGO_DETAILS: ${MONGO_DETAILS}
    depends_on:
      - local_mongo
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  app-net:

volumes:
  my_mongo_data:
EOF

### 6) SHOW USER THE FINAL docker-compose.yml ##################################
echo "[INFO] 6/6: Here is your final docker-compose.yml:"
echo "-------------------------------------------------"
cat docker-compose.yml
echo "-------------------------------------------------"
echo "[DONE] If you see no errors above, volumes are mounted, fstab updated, and docker-compose.yml is ready."
echo "[NEXT] Example usage:"
echo "      docker compose build"
echo "      docker compose up -d"
echo "      docker compose ps"
echo "[TIP]  If you see 'already mounted' in the future, run 'umount /mnt/my_volume' or 'umount /mnt/volume_sfo3_01' first."
