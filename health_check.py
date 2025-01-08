import asyncio
import aiohttp
from typing import Dict, Any, List

class ServiceHealthChecker:
    def __init__(self, config: Dict[str, Any]):
        """
        :param config: The parsed configuration (e.g. from test_config.yaml).
        Expecting config["services"] = { "service_name": {...}, ... }
        """
        self.services = {}
        # Flatten out "services" from the config if needed:
        for key, svcdata in config.items():
            if isinstance(svcdata, dict) and "port" in svcdata:
                self.services[key] = svcdata

    async def check_service(self, name: str, config: dict) -> dict:
        """
        Attempts to connect to /health endpoint. Also checks any dependencies.
        """
        url = f"http://localhost:{config['port']}{config.get('health_endpoint', '/health')}"
        timeout = config.get('health_timeout', 10)
        result = {
            "name": name,
            "port": config["port"],
            "url": url,
            "status": False,
            "dependencies": []
        }

        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=timeout)) as session:
                async with session.get(url) as resp:
                    if resp.status == 200:
                        result["status"] = True
        except Exception as e:
            result["error"] = f"{type(e).__name__}: {str(e)}"

        # Check dependencies recursively
        deps = config.get("dependencies", [])
        if deps:
            for dep in deps:
                if dep in self.services:
                    dep_config = self.services[dep]
                    dep_result = await self.check_service(dep, dep_config)
                    result["dependencies"].append(dep_result)

        return result

    async def run_health_checks(self) -> dict:
        tasks = []
        for svc_name, svc_config in self.services.items():
            tasks.append(self.check_service(svc_name, svc_config))
        results = await asyncio.gather(*tasks, return_exceptions=False)

        # Flatten results into a dict keyed by service name
        final = {}
        for r in results:
            final[r["name"]] = r
        return final
