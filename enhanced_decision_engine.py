from typing import Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field
from tenacity import (
    AsyncRetrying,
    stop_after_attempt,
    wait_exponential,
    CircuitBreaker
)
import structlog
import asyncio
from httpx import AsyncClient, HTTPStatusError
from opentelemetry import trace

class ServiceConfig(BaseModel):
    """Service configuration with circuit breaker settings"""
    name: str
    url: str
    timeout: float = Field(default=30.0)
    max_retries: int = Field(default=3)
    circuit_breaker_failures: int = Field(default=5)
    circuit_breaker_reset_timeout: int = Field(default=60)

class DecisionContext(BaseModel):
    """Decision context validation"""
    transaction_id: str
    user_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    parameters: Dict[str, Any] = Field(default_factory=dict)

class AutonomousDecisionEngine:
    """Enhanced decision engine with tracing, concurrency, and circuit breakers."""

    def __init__(self):
        self.logger = structlog.get_logger()
        self.tracer = trace.get_tracer(__name__)
        
        # Initialize service configurations (could be env-based or from a config file)
        self.services = {
            "openai": ServiceConfig(
                name="openai",
                url="http://openai_service:5000"
            ),
            "oracle": ServiceConfig(
                name="oracle",
                url="http://oracle_service:5000"
            ),
            "memory": ServiceConfig(
                name="memory",
                url="http://ragchain_service:5000"
            )
        }
        
        # Initialize circuit breakers for each service
        self.circuit_breakers = {
            svc_name: CircuitBreaker(
                failure_threshold=svc_config.circuit_breaker_failures,
                recovery_timeout=svc_config.circuit_breaker_reset_timeout
            )
            for svc_name, svc_config in self.services.items()
        }

    async def make_decision(self, context_data: Dict[str, Any]) -> Dict[str, Any]:
        """Orchestrate the decision-making process with concurrency."""
        try:
            # Validate context
            context = DecisionContext(**context_data)
            
            with self.tracer.start_as_current_span("make_decision") as span:
                span.set_attribute("transaction_id", context.transaction_id)
                
                # Fetch data concurrently
                oracle_data, memory_data = await asyncio.gather(
                    self._fetch_oracle_data(context),
                    self._fetch_memory_context(context)
                )
                
                # Get AI analysis
                analysis = await self._fetch_ai_analysis(
                    oracle_data, memory_data, context
                )
                
                # Generate final decision
                decision = self._synthesize_decision(analysis, context)
                
                self.logger.info(
                    "decision.generated",
                    transaction_id=context.transaction_id,
                    decision=decision
                )
                return decision

        except Exception as e:
            self.logger.error(
                "decision.failed",
                error=str(e),
                context=context_data
            )
            raise

    async def _fetch_oracle_data(self, context: DecisionContext) -> Dict[str, Any]:
        """Fetch oracle data with circuit breaker and tenacity retry."""
        svc = self.services["oracle"]
        breaker = self.circuit_breakers["oracle"]

        async with breaker:
            async for attempt in AsyncRetrying(
                stop=stop_after_attempt(svc.max_retries),
                wait=wait_exponential(multiplier=1)
            ):
                with attempt:
                    async with AsyncClient(timeout=svc.timeout) as client:
                        response = await client.get(
                            f"{svc.url}/market-data",
                            params={"transaction_id": context.transaction_id}
                        )
                        response.raise_for_status()
                        return response.json()

    async def _fetch_memory_context(self, context: DecisionContext) -> Dict[str, Any]:
        """Fetch memory context with circuit breaker."""
        svc = self.services["memory"]
        breaker = self.circuit_breakers["memory"]

        async with breaker:
            async for attempt in AsyncRetrying(
                stop=stop_after_attempt(svc.max_retries),
                wait=wait_exponential(multiplier=1)
            ):
                with attempt:
                    async with AsyncClient(timeout=svc.timeout) as client:
                        response = await client.get(
                            f"{svc.url}/query",
                            params={
                                "transaction_id": context.transaction_id,
                                "user_id": context.user_id
                            }
                        )
                        response.raise_for_status()
                        return response.json()

    async def _fetch_ai_analysis(
        self, 
        oracle_data: Dict[str, Any],
        memory_data: Dict[str, Any],
        context: DecisionContext
    ) -> Dict[str, Any]:
        """Fetch AI analysis from openai_service, combining oracle & memory data."""
        svc = self.services["openai"]
        breaker = self.circuit_breakers["openai"]

        payload = {
            "market": oracle_data,
            "history": memory_data
        }

        async with breaker:
            async for attempt in AsyncRetrying(
                stop=stop_after_attempt(svc.max_retries),
                wait=wait_exponential(multiplier=1)
            ):
                with attempt:
                    async with AsyncClient(timeout=svc.timeout) as client:
                        response = await client.post(
                            f"{svc.url}/analyze",
                            json=payload
                        )
                        response.raise_for_status()
                        return response.json()

    def _synthesize_decision(
        self,
        analysis: Dict[str, Any],
        context: DecisionContext
    ) -> Dict[str, Any]:
        """Convert AI analysis + context into a final trading decision."""
        with self.tracer.start_as_current_span("synthesize_decision") as span:
            span.set_attribute("transaction_id", context.transaction_id)

            # Example: compute confidence score
            sentiment = analysis.get("market_analysis", {}).get("sentiment", 0.0)
            pattern_match = analysis.get("historical_context", {}).get("pattern_match", 0.0)
            risk_level = analysis.get("risk_assessment", {}).get("risk_level", 0.5)

            # Avoid division by zero
            confidence_score = (sentiment + pattern_match) / (2 * max(risk_level, 0.1))

            decision = {
                "transaction_id": context.transaction_id,
                "timestamp": datetime.utcnow().isoformat(),
                "action": "HOLD",  # Default
                "confidence": confidence_score,
                "reasoning": [],
                "metadata": {
                    "user_id": context.user_id,
                    "parameters": context.parameters
                }
            }

            # Simple thresholds
            buy_threshold = 0.7
            sell_threshold = 0.3

            if confidence_score >= buy_threshold:
                decision["action"] = "BUY"
                decision["reasoning"].append(
                    f"High confidence ({confidence_score:.2f}) in positive outcome."
                )
            elif confidence_score <= sell_threshold:
                decision["action"] = "SELL"
                decision["reasoning"].append(
                    f"High confidence ({confidence_score:.2f}) in negative outcome."
                )
            else:
                decision["reasoning"].append(
                    f"Neutral confidence ({confidence_score:.2f}), holding."
                )

            # If risk is high, enforce a stop-loss
            if risk_level > 0.8:
                decision["stop_loss"] = True
                decision["reasoning"].append("High risk scenario, enabling stop-loss.")

            return decision

    async def health_check(self) -> Dict[str, Any]:
        """Comprehensive health check of all services and circuit breaker states."""
        checks = {}
        for svc_name, svc_cfg in self.services.items():
            breaker = self.circuit_breakers[svc_name]
            try:
                async with AsyncClient(timeout=5.0) as client:
                    resp = await client.get(f"{svc_cfg.url}/health")
                    checks[svc_name] = {
                        "status": "healthy" if resp.status_code == 200 else "unhealthy",
                        "circuit_breaker": {
                            "state": "closed" if breaker.is_closed() else "open",
                            "failure_count": breaker.failure_count
                        }
                    }
            except Exception as e:
                checks[svc_name] = {
                    "status": "unhealthy",
                    "error": str(e),
                    "circuit_breaker": {
                        "state": "open",
                        "failure_count": breaker.failure_count
                    }
                }
        return checks
