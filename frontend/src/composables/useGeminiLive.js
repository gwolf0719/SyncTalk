import { ref, onUnmounted } from 'vue';
import { useTranslationStore } from '../stores/translation';

export function useGeminiLive() {
    const store = useTranslationStore();
    const socket = ref(null);
    const audioContext = ref(null);
    const processor = ref(null);
    const stream = ref(null);
    const player = ref(null);

    const API_KEY = 'AIzaSyBF3AqVe2qdq-HEIQpVk6Ys3pTZXVjLmh4';
    const WSS_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${API_KEY}`;

    const connect = async () => {
        if (store.isConnected || store.isConnecting) return;

        store.setConnecting(true);
        store.setError(null);

        try {
            socket.value = new WebSocket(WSS_URL);

            socket.value.onopen = () => {
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

                if (data.setupComplete) {
                    store.setConnectionStatus(true);
                    store.setConnecting(false);
                    startRecording();
                    sendSilentChunk(); // Kickstart
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
                store.setError('WebSocket 連線錯誤');
                disconnect();
            };

            socket.value.onclose = () => {
                disconnect();
            };

        } catch (e) {
            store.setError('啟動失敗: ' + e.message);
            disconnect();
        }
    };

    const disconnect = () => {
        socket.value?.close();
        socket.value = null;
        stopRecording();
        store.setConnectionStatus(false);
        store.setConnecting(false);
        store.setVolume(0);
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

    const startRecording = async () => {
        try {
            stream.value = await navigator.mediaDevices.getUserMedia({ audio: true });
            audioContext.value = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
            const source = audioContext.value.createMediaStreamSource(stream.value);
            processor.value = audioContext.value.createScriptProcessor(2048, 1, 1);

            processor.value.onaudioprocess = (e) => {
                const inputData = e.inputBuffer.getChannelData(0);

                // 音量計算
                let sum = 0;
                for (let i = 0; i < inputData.length; i++) {
                    sum += inputData[i] * inputData[i];
                }
                store.setVolume(Math.min(1, Math.sqrt(sum / inputData.length) * 10));

                // 轉換為 PCM16
                const pcm16 = new Int16Array(inputData.length);
                for (let i = 0; i < inputData.length; i++) {
                    pcm16[i] = Math.max(-1, Math.min(1, inputData[i])) * 0x7FFF;
                }

                // 送出
                const base64 = btoa(String.fromCharCode(...new Uint8Array(pcm16.buffer)));
                if (socket.value?.readyState === WebSocket.OPEN) {
                    socket.value.send(JSON.stringify({
                        realtime_input: {
                            media_chunks: [{ mime_type: "audio/pcm;rate=16000", data: base64 }]
                        }
                    }));
                }
            };

            source.connect(processor.value);
            processor.value.connect(audioContext.value.destination);
        } catch (e) {
            store.setError('錄音權限拒絕');
        }
    };

    const stopRecording = () => {
        stream.value?.getTracks().forEach(t => t.stop());
        processor.value?.disconnect();
        audioContext.value?.close();
    };

    const playAudio = (base64) => {
        // 這裡可以使用簡單的 Audio 標記或音訊上下文播放
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

        // 將 PCM16 轉為 Float32 播放
        const pcm16 = new Int16Array(bytes.buffer);
        const float32 = new Float32Array(pcm16.length);
        for (let i = 0; i < pcm16.length; i++) float32[i] = pcm16[i] / 32768.0;

        const playCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 24000 });
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
