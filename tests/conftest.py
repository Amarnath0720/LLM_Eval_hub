import os
import shutil

import pytest
from fastapi.testclient import TestClient


os.environ["OPENAI_API_KEY"] = ""
os.environ["GOOGLE_API_KEY"] = ""
os.environ["GEMINI_API_KEY"] = ""
os.environ["MISTRAL_API_KEY"] = ""


@pytest.fixture(scope="session")
def client(tmp_path_factory):
    database_directory = tmp_path_factory.mktemp("llm-evalhub-tests")
    database_path = database_directory / "test.db"
    os.environ["DATABASE_URL"] = f"sqlite:///{database_path.as_posix()}"

    from app.database import engine
    from app.main import app

    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        engine.dispose()
        shutil.rmtree(database_directory)
