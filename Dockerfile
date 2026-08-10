# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder

WORKDIR /app

#COPY requirements.txt trước, pip install sau và quan trọng là trước khi copy source code. Docker cache theo layer: sửa 1 dòng code sẽ không kiến docker cài lại toàn bộ thư viện (Mỗi lần như vậy tốn vài phút)
COPY requirements.txt .

# --prefix=/install: cài dependency vào thư mục riêng, để stage runtime chỉ cần copy kết quả này sang - không mang theo compiler, giảm dung lượng image
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim AS runtime

WORKDIR /app

# /install -> /usr/local: Python mặc định tìm packege trong /usr/local nên các thư viện cài đặt trở nên import được ngay, không cần pythonpath 
COPY --from=builder /install /usr/local

# Tạo user thường rồi chuyển sang — container chạy root nghĩa là ai
# thoát được khỏi app cũng thành root trên host. UID 10001 không trùng
# với user nào của host, giảm nguy cơ va chạm quyền.
RUN useradd --create-home --uid 10001 appuser

# Copy source code SAU cùng — đây là thứ thay đổi thường xuyên nhất.
# COPY thư mục cụ thể (app, utils) thay vì `COPY . .` để không kéo theo
# file thừa (test, screenshots...) dù .dockerignore đã chặn phần lớn.
COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

# Docker gọi endpoint này mỗi 30s để biết container còn phục vụ được không.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# sh -c để shell mở rộng ${PORT:-8000}: cloud (Railway/Render/Cloud Run)
# tự gán cổng qua biến PORT, không phải lúc nào cũng 8000.
# 0.0.0.0 chứ không phải 127.0.0.1 — bind localhost thì bên ngoài container
# không gọi vào được.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
