FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 7860

# 单 worker：任务状态存进程内存，多 worker 会查不到任务
CMD ["gunicorn", "-w", "1", "--threads", "8", "--timeout", "1800", "-b", "0.0.0.0:7860", "server:app"]
