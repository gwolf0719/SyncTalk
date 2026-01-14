<script setup>
import { computed } from 'vue';
import { useTranslationStore } from '../stores/translation';

const store = useTranslationStore();

// 簡單將頻譜數據轉換為適合 CSS 高度的陣列 (取前 32 個頻點)
const visualizerBars = computed(() => {
  if (!store.audioSpectrum || store.audioSpectrum.length === 0) {
    return new Array(32).fill(5); // 靜止狀態稍微有點高度
  }
  // 取樣間隔，取低頻為主
  const step = Math.floor(store.audioSpectrum.length / 64);
  const bars = [];
  for (let i = 0; i < 32; i++) {
    const value = store.audioSpectrum[i * step] || 0;
    // 將 0-255 映射到 5-100%
    bars.push(Math.max(5, (value / 255) * 100)); 
  }
  return bars;
});
</script>

<template>
  <div class="flex items-end justify-center gap-[2px] h-12 w-full overflow-hidden px-4">
    <div 
      v-for="(height, index) in visualizerBars" 
      :key="index"
      class="w-2 rounded-full bg-indigo-500 transition-all duration-75 ease-out shadow-sm"
      :style="{ height: height + '%', opacity: store.isConnected ? 1 : 0.3 }"
    ></div>
  </div>
</template>
