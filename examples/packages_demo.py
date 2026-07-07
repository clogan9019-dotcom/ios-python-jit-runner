import sys
print("Python:", sys.version)
try:
    import requests
    print("requests version:", requests.__version__)
except Exception as exc:
    print("requests not installed or failed:", exc)
