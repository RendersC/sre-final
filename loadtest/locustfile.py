"""Locust load test for ecom-api.

Usage (headless):
    locust -f locustfile.py --headless \
           --host http://localhost:30081 \
           --users 200 --spawn-rate 20 --run-time 5m

Usage (web UI):
    locust -f locustfile.py --host http://localhost:30081
    # then open http://localhost:8089

The traffic profile mixes browsing (70%), product detail (20%) and order
creation (10%), which is realistic for an e-commerce front-end and exercises
the same routes that our SLI dashboard measures.
"""

import random

from locust import HttpUser, LoadTestShape, between, task


PRODUCT_IDS = [1, 2, 3, 4, 5]


class EcomUser(HttpUser):
    wait_time = between(0.2, 1.2)

    @task(7)
    def list_products(self) -> None:
        self.client.get("/api/products", name="GET /api/products")

    @task(2)
    def view_product(self) -> None:
        pid = random.choice(PRODUCT_IDS)
        self.client.get(f"/api/products/{pid}", name="GET /api/products/{id}")

    @task(1)
    def place_order(self) -> None:
        payload = {
            "product_id": random.choice(PRODUCT_IDS),
            "quantity": random.randint(1, 3),
        }
        with self.client.post(
            "/api/orders",
            json=payload,
            name="POST /api/orders",
            catch_response=True,
        ) as resp:
            # 422 is a legitimate "insufficient stock" response under load,
            # so do not mark it as a failure in Locust statistics.
            if resp.status_code in (201, 422):
                resp.success()
            else:
                resp.failure(f"unexpected status {resp.status_code}")

    @task(2)
    def cpu_work(self) -> None:
        ms = random.randint(20, 120)
        self.client.get(f"/api/work?ms={ms}", name="GET /api/work")


class StagedSpike(LoadTestShape):
    """Ramp -> steady -> spike -> cool-down. Demonstrates HPA scaling."""

    stages = [
        {"duration": 60,  "users": 30,  "spawn_rate": 10},
        {"duration": 180, "users": 80,  "spawn_rate": 20},
        {"duration": 300, "users": 250, "spawn_rate": 50},   # spike triggers HPA
        {"duration": 420, "users": 80,  "spawn_rate": 20},
        {"duration": 480, "users": 10,  "spawn_rate": 10},
    ]

    def tick(self):
        run_time = self.get_run_time()
        for stage in self.stages:
            if run_time < stage["duration"]:
                return (stage["users"], stage["spawn_rate"])
        return None
