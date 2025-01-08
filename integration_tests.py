import asyncio
import yaml
import json
import sys

from health_check import ServiceHealthChecker
from mongo_validator import MongoValidator

import httpx
from typing import Dict, Any

class IntegrationTester:
    def __init__(self, config: Dict[str, Any]):
        self.config = config

    async def test_quant_workflow(self) -> dict:
        """
        Example test simulating a call to the quant service,
        which in turn should call oracle + ragchain + openai.
        """
        if "quant_service" not in self.config:
            return {
                "workflow": "quant_analysis",
                "status": "failed",
                "error": "No 'quant_service' config found."
            }

        quant_port = self.config["quant_service"]["port"]
        url = f"http://localhost:{quant_port}/decision"
        payload = {
            "transaction_id": "tx-12345",
            "user_id": "user-5678",
            "parameters": { "asset": "BTC", "amount": 1.2 }
        }
        timeout_value = self.config.get("test_settings", {}).get("integration_timeout", 15)

        async with httpx.AsyncClient(timeout=timeout_value) as client:
            try:
                resp = await client.post(url, json=payload)
                if resp.status_code == 200:
                    return {
                        "workflow": "quant_analysis",
                        "status": "success",
                        "response": resp.json()
                    }
                else:
                    return {
                        "workflow": "quant_analysis",
                        "status": "failed",
                        "error": f"HTTP {resp.status_code}",
                        "response_text": resp.text
                    }
            except Exception as e:
                return {
                    "workflow": "quant_analysis",
                    "status": "failed",
                    "error": str(e)
                }

async def run_all_tests(config: Dict[str, Any]) -> Dict[str, Any]:
    results = {
        "health_checks": {},
        "mongodb_validation": {},
        "integration_tests": {}
    }

    # 1) Health Checks
    health_checker = ServiceHealthChecker(config)
    health_results = await health_checker.run_health_checks()
    results["health_checks"] = health_results

    # 2) MongoDB Validation (example usage)
    mongo_uri = config["mongodb"]["uri"]
    db_name = config["mongodb"]["db_name"]
    mongo_val = MongoValidator(uri=mongo_uri, db_name=db_name)

    try:
        await mongo_val.connect()
        # Suppose we check if "memory" collection exists:
        coll_checks = await mongo_val.validate_collections(["memory"])
        results["mongodb_validation"]["collections"] = coll_checks

        # Optional: schema check example
        # schema = {...} # define a JSON schema
        # schema_result = await mongo_val.validate_document_schema("memory", schema)
        # results["mongodb_validation"]["schema_check"] = schema_result

    except Exception as e:
        results["mongodb_validation"]["error"] = str(e)
    finally:
        await mongo_val.disconnect()

    # 3) Integration Tester
    tester = IntegrationTester(config)
    quant_result = await tester.test_quant_workflow()
    results["integration_tests"]["quant_workflow"] = quant_result

    return results

def main():
    # Load config from YAML
    with open("test_config.yaml", "r") as f:
        config = yaml.safe_load(f)

    # Flatten config["services"] into top-level keys for convenience
    if "services" in config:
        for k, v in config["services"].items():
            config[k] = v

    # Use asyncio.run in Python 3.12+ to avoid DeprecationWarning
    final_results = asyncio.run(run_all_tests(config))

    # Print results
    print(json.dumps(final_results, indent=2))

    # Decide exit code (0 if all healthy & successful, else 1)
    # 1) Check health checks
    all_healthy = all(svc["status"] for svc in final_results["health_checks"].values())
    if not all_healthy:
        sys.exit(1)

    # 2) Check integration
    quant_status = final_results["integration_tests"]["quant_workflow"]["status"]
    if quant_status != "success":
        sys.exit(1)

    # If we get here, assume tests passed
    sys.exit(0)

if __name__ == "__main__":
    main()
