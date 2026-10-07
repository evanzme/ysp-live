FROM python:3.12-alpine

LABEL description="央视频全频道直播代理 v9.0（Python 主网关 + Node.js 网页版兜底引擎，单端口）"

ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    YSP_DATA_DIR=/app/data

# nodejs 用于运行网页版兜底引擎 ysp-engine.js
RUN apk add --no-cache nodejs tzdata

WORKDIR /app

COPY ysp-live.py ysp-engine.js ./

RUN mkdir -p /app/data

VOLUME ["/app/data"]

EXPOSE 8767

CMD ["python3", "-u", "ysp-live.py"]
