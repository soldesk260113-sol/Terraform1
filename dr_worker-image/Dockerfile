FROM python:3.11-slim

WORKDIR /app

# 필요한 패키지 설치
RUN pip install --no-cache-dir \
    boto3 \
    requests

# DR Worker 스크립트 복사
COPY dr_worker.py /app/

# 실행 권한
RUN chmod +x /app/dr_worker.py

# Health Check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import sys; sys.exit(0)"

# 실행
CMD ["python", "/app/dr_worker.py"]
