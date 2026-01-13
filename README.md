# SyncTalk (Flutter)

SyncTalk 是一個專為中日交流設計的 Android 即時翻譯應用，採用 **Flutter** 開發，並整合 **Google Gemini Multimodal Live API** 實現低延遲的語音對語音翻譯。

## 最新版本更新 (2026-01-14)
- **全新品牌識別**：
  - 設計了專屬的平面化 Icon 與 Logo，符合 Android 最新自適應圖示 (Adaptive Icons) 規範。
  - 品牌色調：Electric Blue (#2962FF)。
- **UI/UX 大重構**：
  - 採用極簡平面設計 (Flat Design)，移除漸層與複雜裝飾。
  - **專注展示模式**：主畫面改為展示巨大的日文翻譯（給對方看），下方輔助顯示中文參考。
  - **動態視覺反饋**：Mic 按鈕現在會隨音量大小動態縮放與閃爍。
- **技術架構優化**：
  - 更新至 Gemini v1beta WebSocket API。
  - 整合 `mic_stream` 提升音訊採集穩定性。
  - 優化音訊串流邏輯，包含封裝頭處理與音量偵測。
  - 增加完善的連線錯誤處理機制。

## 功能特色
- **即時雙向翻譯**：透過 WebSocket 串流音訊至 Gemini，實現趨近自然的對話體驗。
- **專注展示介面**：大字體顯示日文翻譯結果，方便日本友人閱讀。
- **智慧語音偵測**：自動分辨中日文輸入並更新相對應顯示區域。
- **聲波視覺化**：直觀的音量反饋。

## 技術堆疊
- **Framework**: Flutter (Dart)
- **API**: Google Gemini Multimodal Live API (v1beta WebSocket)
- **State Management**: Provider
- **Audio Output**: sound_stream
- **Audio Input**: mic_stream
- **Icons**: Adaptive Icons support

## 開發設定
1. 複製 `.env.example` 為 `.env` 並填入 `GEMINI_API_KEY`。
2. 執行 `flutter pub get` 安裝依賴。
3. 執行 `flutter run` 啟動專案。

## 專案結構
- `lib/services/`: 包含 Gemini WebSocket 與音訊處理邏輯。
- `lib/ui/`: 包含主介面 `HomeScreen`。
- `assets/images/`: 品牌 Logo 與資源。
