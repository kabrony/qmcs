# SOLAIS: Solana AI Trading System Overview

This document provides an overview of the SOLAIS system—a Solana and AI-powered trading system.

## Architecture

- **solana_agents (Node.js)**: Orchestrator & API gateway, calls ragchain_service & quant_service.
- **ragchain_service (Python FastAPI)**: Stores ephemeral AI thoughts in MongoDB.
- **quant_service (Python FastAPI)**: Offers quant logic & circuit-breaker checks.
- **mongo (Docker)**: MongoDB instance for ephemeral data storage.
- **solana_ai_trader.py (Python)**: Trading logic that uses OpenAI, Google Gemini, Tavily, and Solana blockchain calls.

## Key Features

- **Containerized**: Easy Docker setup.
- **AI Integration**: Multi-LLM approach (OpenAI, Gemini, Tavily).
- **Ephemeral Memory**: Chain-of-thought debug logs in MongoDB.
- **Monitoring**: `final_extreme_monitor_v5.sh` checks logs, container health, CPU & memory usage.

## Quick Start

1. **Set `.env`**: Provide your MONGO_DETAILS, SOLANA keys, and LLM keys in `.env`.
2. **Build & Start**:  
   ```bash
   docker compose build

   docker compose up -d
