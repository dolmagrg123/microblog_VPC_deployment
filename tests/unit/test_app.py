import os
import sys
import pytest

# Add the project root directory to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from microblog import app  # Import the app now that the path is correct

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_homepage(client):
    """Test if the homepage loads correctly."""
    response = client.get('/', follow_redirects=True)
    assert response.status_code == 200
    assert b"Sign In" in response.data
