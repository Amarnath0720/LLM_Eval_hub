from fastapi.testclient import TestClient

def test_root_endpoint(client: TestClient):
    response = client.get("/")
    assert response.status_code == 200


def test_health_endpoint_checks_database(client: TestClient):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_prompts_endpoint(client: TestClient):
    response = client.get("/prompts")
    assert response.status_code == 200
    assert isinstance(response.json(), (list, dict))
    assert {prompt["version"] for prompt in response.json()} == {"v1", "v2"}


def test_prompt_version_endpoint(client: TestClient):
    response = client.get("/prompts/v1")
    assert response.status_code == 200
    assert response.json() is not None


def test_datasets_endpoint(client: TestClient):
    response = client.get("/datasets")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_create_dataset(client: TestClient):
    payload = {
        "name": "Automated API Test Dataset",
        "prompts": [
            {
                "question": "What is machine learning?",
                "context": "Machine learning enables systems to learn patterns from data.",
                "expected_output": "Machine learning enables systems to learn patterns from data.",
                "category": "AI Fundamentals",
                "difficulty": "Easy",
            }
        ],
    }

    response = client.post("/datasets", json=payload)

    assert response.status_code in (200, 201)
    assert response.json() is not None


def test_create_dataset_rejects_missing_name(client: TestClient):
    payload = {
        "prompts": [
            {
                "question": "What is Python?"
            }
        ]
    }

    response = client.post("/datasets", json=payload)

    assert response.status_code == 422


def test_create_dataset_rejects_missing_prompts(client: TestClient):
    payload = {
        "name": "Invalid Dataset"
    }

    response = client.post("/datasets", json=payload)

    assert response.status_code == 422


def test_nonexistent_run_returns_not_found(client: TestClient):
    response = client.get("/runs/999999999")

    assert response.status_code == 404


def test_nonexistent_run_results_returns_not_found(client: TestClient):
    response = client.get("/runs/999999999/results")

    assert response.status_code == 404


def test_nonexistent_run_judge_results_returns_not_found(client: TestClient):
    response = client.get("/runs/999999999/judge-results")

    assert response.status_code == 404


def test_compare_requires_run_ids(client: TestClient):
    response = client.get("/compare")

    assert response.status_code == 422


def test_mock_evaluation_run_persists_results(client: TestClient):
    dataset_response = client.post(
        "/datasets",
        json={
            "name": "Mock evaluation test",
            "prompts": [
                {
                    "question": "What is Python?",
                    "context": "Python is a programming language.",
                    "expected_output": "Python is a programming language.",
                }
            ],
        },
    )
    assert dataset_response.status_code == 200
    dataset_id = dataset_response.json()["dataset_id"]
    prompts_response = client.get(f"/datasets/{dataset_id}/prompts")
    assert prompts_response.status_code == 200
    assert prompts_response.json()[0]["question"] == "What is Python?"

    run_response = client.post(
        "/runs",
        json={
            "name": "Mock evaluation run",
            "dataset_id": dataset_id,
            "models": ["mock-model"],
            "prompt_version": "v1",
        },
    )

    assert run_response.status_code == 200
    run = run_response.json()
    assert run["status"] == "completed"
    assert run["response_count"] == 1
    assert run["standard_score_count"] == 7
    assert run["judge_score_count"] == 5

    results_response = client.get(f"/runs/{run['run_id']}/results")
    assert results_response.status_code == 200
    assert len(results_response.json()) == 1
