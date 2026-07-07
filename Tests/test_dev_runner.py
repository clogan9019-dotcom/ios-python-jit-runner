from pathlib import Path


def test_examples_exist():
    root = Path(__file__).resolve().parents[1]
    assert (root / "examples" / "hello.py").exists()
    assert (root / "Scripts" / "dev_runner.py").exists()
