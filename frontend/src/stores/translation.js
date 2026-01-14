import { defineStore } from 'pinia';

export const useTranslationStore = defineStore('translation', {
  state: () => ({
    chineseText: '',
    japaneseText: '',
    isConnected: false,
    isConnecting: false,
    errorMessage: null,
    volume: 0,
    audioSpectrum: new Uint8Array(0),
    isSilent: false,
    countdown: 0,
  }),
  actions: {
    setChineseText(text) {
      this.chineseText = text;
    },
    setJapaneseText(text) {
      this.japaneseText = text;
    },
    setConnectionStatus(status) {
      this.isConnected = status;
    },
    setConnecting(status) {
      this.isConnecting = status;
    },
    setError(msg) {
      this.errorMessage = msg;
    },
    setVolume(v) {
      this.volume = v;
    },
    setAudioSpectrum(data) {
      this.audioSpectrum = data;
    },
    setSilentStatus(status) {
      this.isSilent = status;
    },
    setCountdown(v) {
      this.countdown = v;
    }
  }
});
