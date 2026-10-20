from fastapi.testclient import TestClient

from app import main

client = TestClient(main.app)


def test_health_check():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_answer_requires_evidence():
    response = client.post(
        "/v1/answer",
        json={"question": "What is this document about?", "evidence": []},
    )

    assert response.status_code == 422


def test_answer_endpoint_returns_grounded_answer(monkeypatch):
    def fake_generate_answer(request):
        return main.AnswerResponse(
            answer="The contract starts on 1 January. [Contract.pdf, p. 2]",
            model="test-model",
        )

    monkeypatch.setattr(main, "generate_answer", fake_generate_answer)

    response = client.post(
        "/v1/answer",
        json={
            "question": "When does the contract start?",
            "evidence": [
                {
                    "document_title": "Contract.pdf",
                    "page": 2,
                    "excerpt": "The contract starts on 1 January.",
                }
            ],
        },
    )

    assert response.status_code == 200
    assert "Contract.pdf, p. 2" in response.json()["answer"]
    assert response.json()["model"] == "test-model"
