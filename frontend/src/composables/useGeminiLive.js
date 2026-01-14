import { ref, onUnmounted } from 'vue';
import { useTranslationStore } from '../stores/translation';

export function useGeminiLive() {
    const store = useTranslationStore();
    const socket = ref(null);
    const audioContext = ref(null);
    const processor = ref(null);
    const stream = ref(null);
    const animationFrameId = ref(null);

    // 獨立的監聽旗標
    const silentStartTime = ref(null);
    const countdownStartTime = ref(null);
    const isCountingDown = ref(false);

    const API_KEY = 'AIzaSyBF3AqVe2qdq-HEIQpVk6Ys3pTZXVjLmh4';
    const WSS_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${API_KEY}`;

    const connect = async () => {
        if (store.isConnected || store.isConnecting) return;

        store.setConnecting(true);
        store.setError(null);

        try {
            // 先啟動音訊，成功後再建立 WebSocket
            await startAudio();

            socket.value = new WebSocket(WSS_URL);

            socket.value.onopen = () => {
                console.log('[WebSocket] 連線成功');
                const setupMsg = {
                    setup: {
                        model: "models/gemini-1.5-flash",
                        generation_config: { response_modalities: ["AUDIO", "TEXT"] },
                        system_instruction: {
                            parts: [{ text: "You are a professional bi-directional translator between Chinese and Japanese. When you hear Chinese, translate to Japanese. When you hear Japanese, translate to Chinese." }]
                        },
                    }
                };
                socket.value.send(JSON.stringify(setupMsg));
            };

            socket.value.onmessage = async (event) => {
                const data = JSON.parse(event.data);
                console.log('[WebSocket] 收到訊息:', data);

                if (data.setupComplete) {
                    console.log('[WebSocket] 設定完成，連線已建立');
                    store.setConnectionStatus(true);
                    store.setConnecting(false);
                    sendSilentChunk();
                }

                if (data.serverContent || data.modelTurn) {
                    const parts = (data.serverContent?.modelTurn?.parts || data.modelTurn?.parts) || [];
                    for (const part of parts) {
                        if (part.text) {
                            const text = part.text;
                            if (/[\u3040-\u309F\u30A0-\u30FF]/.test(text)) {
                                store.setJapaneseText(text);
                            } else {
                                store.setChineseText(text);
                            }
                        }
                        if (part.inlineData) {
                            playAudio(part.inlineData.data);
                        }
                    }
                }
            };

            socket.value.onerror = (e) => {
                console.error('[WebSocket] 錯誤:', e);
                if (store.isConnected) {
                    store.setError('連線中斷');
                }
                disconnect();
            };

            socket.value.onclose = () => {
                console.log('[WebSocket] 連線關閉');
                disconnect();
            };

        } catch (e) {
            console.error('[連線失敗]', e);
            store.setError('啟動失敗: ' + (e.message || '無法存取麥克風'));
            disconnect();
        }
    };

    const disconnect = () => {
        if (socket.value) {
            socket.value.close();
            socket.value = null;
        }
        stopAudio();
        store.setConnectionStatus(false);
        store.setConnecting(false);
        store.setVolume(0);

        store.setSilentStatus(false);
        store.setCountdown(0);
        silentStartTime.value = null;
        countdownStartTime.value = null;
        isCountingDown.value = false;
    };

    const sendSilentChunk = () => {
        const silent = new Uint8Array(3200).fill(0);
        const base64 = btoa(String.fromCharCode(...silent));
        socket.value?.send(JSON.stringify({
            realtime_input: {
                media_chunks: [{ mime_type: "audio/pcm;rate=16000", data: base64 }]
            }
        }));
    };

    const startAudio = async () => {
        console.log('[音訊] 開始初始化...');

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw new Error('瀏覽器不支持錄音功能');
        }

        // 使用更寬鬆的 constraints，提高兼容性
        try {
            stream.value = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: { ideal: true },
                    noiseSuppression: { ideal: true },
                    autoGainControl: { ideal: true }
                }
            });
            console.log('[音訊] 麥克風存取成功');
        } catch (err) {
            console.error('[音訊] getUserMedia 失敗:', err);
            throw new Error('無法存取麥克風: ' + err.message);
        }

        // 建立 AudioContext（使用系統預設採樣率，稍後降採樣）
        if (!audioContext.value || audioContext.value.state === 'closed') {
            audioContext.value = new (window.AudioContext || window.webkitAudioContext)();
            console.log('[音訊] AudioContext 已建立，採樣率:', audioContext.value.sampleRate);
        }

        // 確保 AudioContext 處於運行狀態
        if (audioContext.value.state === 'suspended') {
            await audioContext.value.resume();
            console.log('[音訊] AudioContext 已恢復');
        }

        const source = audioContext.value.createMediaStreamSource(stream.value);
        const analyser = audioContext.value.createAnalyser();
        analyser.fftSize = 256;
        source.connect(analyser);

        const dataArray = new Uint8Array(analyser.frequencyBinCount);

        const updateVisualizer = () => {
            if (!audioContext.value || audioContext.value.state === 'closed') return;

            analyser.getByteFrequencyData(dataArray);
            store.setAudioSpectrum(new Uint8Array(dataArray));

            // 計算音量
            let sum = 0;
            for (let i = 0; i < dataArray.length; i++) {
                sum += dataArray[i];
            }
            const avg = sum / dataArray.length;
            const volume = Math.min(1, avg / 128);
            store.setVolume(volume);

            // DEBUG: 每秒輸出一次音量數值
            if (!window.lastVolumeLog || Date.now() - window.lastVolumeLog > 1000) {
                console.log('[音訊] avg:', avg.toFixed(2), 'volume:', volume.toFixed(3), 'isConnecting:', store.isConnecting, 'isConnected:', store.isConnected);
                window.lastVolumeLog = Date.now();
            }

            // 無聲偵測邏輯（只在連線中或已連線時執行）
            if (store.isConnecting || store.isConnected) {
                const now = Date.now();

                if (avg < 10) { // 靜默閾值（提高到 10）
                    if (!silentStartTime.value) {
                        silentStartTime.value = now;
                        console.log('[靜默偵測] 開始計時，avg:', avg);
                    } else if (!isCountingDown.value) {
                        const silentDuration = now - silentStartTime.value;
                        if (silentDuration > 5000) { // 5秒靜默
                            console.log('[靜默偵測] 進入倒數階段，靜默時長:', silentDuration);
                            isCountingDown.value = true;
                            countdownStartTime.value = now;
                            store.setSilentStatus(true);
                        }
                    } else {
                        // 倒數中
                        const elapsed = now - countdownStartTime.value;
                        const remaining = Math.max(0, 3 - Math.floor(elapsed / 1000));
                        store.setCountdown(remaining);
                        console.log('[靜默偵測] 倒數:', remaining);

                        if (remaining === 0 && elapsed >= 3000) {
                            console.log('[靜默偵測] 倒數結束，自動關閉');
                            store.setError('偵測不到聲音，已自動關閉通話。');
                            disconnect();
                            return;
                        }
                    }
                } else {
                    // 偵測到聲音，重置計時器
                    if (silentStartTime.value || isCountingDown.value) {
                        console.log('[靜默偵測] 偵測到聲音，重置計時器，avg:', avg);
                        silentStartTime.value = null;
                        isCountingDown.value = false;
                        countdownStartTime.value = null;
                        store.setSilentStatus(false);
                        store.setCountdown(0);
                    }
                }
            }

            animationFrameId.value = requestAnimationFrame(updateVisualizer);
        };

        console.log('[音訊] 啟動視覺化循環');
        requestAnimationFrame(updateVisualizer);

        // 使用 ScriptProcessor 處理音訊數據並發送
        const bufferSize = 4096;
        processor.value = audioContext.value.createScriptProcessor(bufferSize, 1, 1);

        const inputSampleRate = audioContext.value.sampleRate;
        const targetSampleRate = 16000;

        console.log('[音訊] 採樣率:', inputSampleRate, '→', targetSampleRate);

        processor.value.onaudioprocess = (e) => {
            if (socket.value?.readyState !== WebSocket.OPEN) return;

            const inputData = e.inputBuffer.getChannelData(0);

            // 降採樣至 16kHz (如果需要)
            let finalData = inputData;
            if (inputSampleRate !== targetSampleRate) {
                finalData = downsampleBuffer(inputData, inputSampleRate, targetSampleRate);
            }

            // 轉換為 PCM16 並增加音量增益
            const pcm16 = new Int16Array(finalData.length);
            for (let i = 0; i < finalData.length; i++) {
                // 增加 1.5 倍增益，避免聲音太小
                let s = Math.max(-1, Math.min(1, finalData[i] * 1.5));
                pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
            }

            // 發送至 WebSocket
            const base64 = btoa(String.fromCharCode(...new Uint8Array(pcm16.buffer)));
            socket.value.send(JSON.stringify({
                realtime_input: {
                    media_chunks: [{ mime_type: "audio/pcm;rate=16000", data: base64 }]
                }
            }));
        };

        // 關鍵修復：加入靜音 GainNode 避免回音
        const gainNode = audioContext.value.createGain();
        gainNode.gain.value = 0; // 音量設為 0，騙過瀏覽器讓 ScriptProcessor 運作

        source.connect(processor.value);
        processor.value.connect(gainNode);
        gainNode.connect(audioContext.value.destination);

        console.log('[音訊] 音訊處理管線已建立 (含靜音節點)');
    };

    // 降採樣函數
    function downsampleBuffer(buffer, inputRate, outputRate) {
        if (outputRate === inputRate) return buffer;

        const ratio = inputRate / outputRate;
        const newLength = Math.round(buffer.length / ratio);
        const result = new Float32Array(newLength);

        for (let i = 0; i < newLength; i++) {
            const start = Math.floor(i * ratio);
            const end = Math.min(Math.floor((i + 1) * ratio), buffer.length);
            let sum = 0;
            for (let j = start; j < end; j++) {
                sum += buffer[j];
            }
            result[i] = sum / (end - start);
        }

        return result;
    }

    const stopAudio = () => {
        console.log('[音訊] 停止音訊處理');

        if (animationFrameId.value) {
            cancelAnimationFrame(animationFrameId.value);
            animationFrameId.value = null;
        }

        if (stream.value) {
            stream.value.getTracks().forEach(t => t.stop());
            stream.value = null;
        }

        if (processor.value) {
            processor.value.disconnect();
            processor.value = null;
        }

        if (audioContext.value && audioContext.value.state !== 'closed') {
            audioContext.value.close();
            audioContext.value = null;
        }
    };

    const playAudio = (base64) => {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

        const pcm16 = new Int16Array(bytes.buffer);
        const float32 = new Float32Array(pcm16.length);
        for (let i = 0; i < pcm16.length; i++) float32[i] = pcm16[i] / 32768.0;

        const playCtx = audioContext.value || new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 24000 });
        if (playCtx.state === 'suspended') playCtx.resume();

        const buffer = playCtx.createBuffer(1, float32.length, 24000);
        buffer.getChannelData(0).set(float32);
        const source = playCtx.createBufferSource();
        source.buffer = buffer;
        source.connect(playCtx.destination);
        source.start();
    };

    onUnmounted(() => disconnect());

    return { connect, disconnect };
}
