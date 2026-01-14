# 階段 1: 建構前端
FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
RUN npm run build

# 階段 2: 執行環境
FROM python:3.11-slim
WORKDIR /app

# 複製後端與前端產物
COPY backend/ ./backend
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

# 安裝 Python 依賴
WORKDIR /app/backend
RUN pip install --no-cache-dir -r requirements.txt

# 設定環境變數
ENV PORT=8080
ENV GEMINI_API_KEY=AIzaSyBF3AqVe2qdq-HEIQpVk6Ys3pTZXVjLmh4

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "main:app"]
