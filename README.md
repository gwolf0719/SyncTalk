# SyncTalk Web

SyncTalk 是一個純網頁架構的中日翻譯系統，利用 **Gemini 1.5 Flash** 的即時多模態能力實現流暢的語音互譯。

## 技術棧
- **前端**: Vue 3 + Pinia + Tailwind CSS + Lucide Icons
- **後端**: Python (Flask) -> 僅作為靜態檔案託管伺服器
- **容器化**: Docker (多階段建構)
- **部署**: Cloud Run 支援

## 功能特點
- **即時翻譯**: 透過 WebSocket 連接 Gemini API。
- **質感 UI**: 深色模式、現代佈局與動態音量反饋。
- **純網頁架構**: 支援所有現代瀏覽器（需 HTTPS 以獲得麥克風權限）。

## 部署至 Cloud Run
透過提供的 Dockerfile 進行打包建構：
```bash
# 設定專案編號
PROJECT_ID=[您的 PROJECT_ID]

# 建構並推送
gcloud builds submit --tag gcr.io/$PROJECT_ID/synctalk

# 部署
gcloud run deploy synctalk \
  --image gcr.io/$PROJECT_ID/synctalk \
  --platform managed \
  --set-env-vars="GEMINI_API_KEY=[您的_API_KEY]" \
  --allow-unauthenticated
```

## 注意事項
- 麥克風功能在 **localhost** 或 **HTTPS** 環境下才能正常運作。
- 本專案已將 API KEY 寫入環境變數預設值（部署時建議替換）。
