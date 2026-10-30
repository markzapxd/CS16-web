FROM python:3.12-slim
COPY build/provision-data.py /tools/provision-data.py
ENTRYPOINT ["python3", "-I", "/tools/provision-data.py"]
