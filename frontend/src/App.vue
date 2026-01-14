<script setup>
import { useTranslationStore } from './stores/translation';
import { useGeminiLive } from './composables/useGeminiLive';
import { Mic, MicOff, Languages, MessageSquare } from 'lucide-vue-next';
import AudioVisualizer from './components/AudioVisualizer.vue';

const store = useTranslationStore();
const { connect, disconnect } = useGeminiLive();

const toggleConnection = () => {
  if (store.isConnected) {
    disconnect();
  } else {
    connect();
  }
};
</script>

<template>
  <div class="min-h-screen bg-gray-50 text-gray-900 font-sans flex flex-col items-center relative">
    
    <!-- 無聲倒數提示遮罩 -->
    <div v-if="store.isSilent" class="fixed inset-0 z-[60] flex items-center justify-center bg-white/60 backdrop-blur-md transition-all duration-500">
      <div class="text-center p-12 bg-white rounded-[40px] shadow-2xl border border-red-50 flex flex-col items-center gap-6 transform scale-110">
        <div class="relative w-24 h-24 flex items-center justify-center">
          <div class="absolute inset-0 border-4 border-red-100 rounded-full"></div>
          <div class="absolute inset-0 border-4 border-red-500 rounded-full animate-ping opacity-20"></div>
          <span class="text-6xl font-black text-red-500 tabular-nums">{{ store.countdown }}</span>
        </div>
        <div>
          <h2 class="text-2xl font-bold text-gray-800">偵測不到聲音</h2>
          <p class="text-gray-500 mt-2 font-medium">通話即將在倒數結束後關閉...</p>
        </div>
        <div class="w-full h-1.5 bg-gray-100 rounded-full mt-4 overflow-hidden">
          <div class="h-full bg-red-500 transition-all duration-1000 ease-linear" :style="{ width: (store.countdown / 3 * 100) + '%' }"></div>
        </div>
        <p class="text-indigo-600 font-bold animate-pulse text-sm mt-2">請說話以繼續通話</p>
      </div>
    </div>

    <!-- 全域錯誤提示 Banner -->
    <div v-if="store.errorMessage" class="w-full bg-red-500 text-white px-6 py-3 text-center font-medium shadow-md animate-bounce sticky top-0 z-50">
      <div class="flex items-center justify-center gap-2">
        <span class="bg-white text-red-600 rounded-full w-5 h-5 flex items-center justify-center font-bold text-xs">!</span>
        {{ store.errorMessage }}
      </div>
    </div>

    <!-- 頂部導航與控制區 -->
    <header class="w-full max-w-5xl px-6 py-8 flex flex-col md:flex-row justify-between items-center gap-6">
      <div class="flex items-center gap-3">
        <div class="bg-indigo-600 p-3 rounded-2xl shadow-lg shadow-indigo-500/20">
          <Languages class="w-8 h-8 text-white" />
        </div>
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-gray-800">SyncTalk</h1>
          <p class="text-sm text-gray-500">即時雙向翻譯助手</p>
        </div>
      </div>

      <!-- 常駐聲紋區域 (Header 中間) -->
      <div class="flex-1 w-full max-w-md mx-6 h-16 bg-white rounded-2xl shadow-sm border border-gray-100 flex items-end pb-2 overflow-hidden">
        <AudioVisualizer />
      </div>
      
      <button 
        @click="toggleConnection"
        :disabled="store.isConnecting"
        class="group relative flex items-center gap-2 px-8 py-4 rounded-xl font-bold text-lg transition-all duration-300 shadow-md hover:shadow-xl transform hover:-translate-y-0.5 active:translate-y-0"
        :class="store.isConnected ? 'bg-white text-red-500 border-2 border-red-100 hover:bg-red-50' : 'bg-indigo-600 text-white hover:bg-indigo-700'"
      >
        <span v-if="store.isConnecting" class="animate-spin rounded-full h-5 w-5 border-2 border-white/30 border-t-white"></span>
        <template v-else>
          <Mic v-if="!store.isConnected" class="w-5 h-5" />
          <MicOff v-else class="w-5 h-5" />
          {{ store.isConnected ? '結束通話' : '開始對話' }}
        </template>
      </button>
    </header>

    <!-- 主要內容區 -->
    <main class="w-full max-w-5xl grid grid-cols-1 md:grid-cols-2 gap-6 px-6 pb-12 flex-1">
      
      <!-- 中文區塊 -->
      <section class="flex flex-col h-full">
        <div class="flex items-center gap-2 text-gray-400 mb-3 px-2">
          <div class="w-2 h-2 rounded-full bg-teal-500"></div>
          <span class="text-xs font-bold uppercase tracking-widest">中文 (Chinese)</span>
        </div>
        <div class="flex-1 bg-white border border-gray-100 rounded-3xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-shadow duration-300 min-h-[400px] flex flex-col relative overflow-hidden group">
          <div class="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
            <MessageSquare class="w-24 h-24 text-teal-500" />
          </div>
          <p class="text-2xl leading-relaxed text-gray-700 font-medium overflow-y-auto z-10 whitespace-pre-wrap">
            {{ store.chineseText || '請點擊「開始對話」並說中文...' }}
          </p>
        </div>
      </section>

      <!-- 日文區塊 -->
      <section class="flex flex-col h-full">
        <div class="flex items-center gap-2 text-gray-400 mb-3 px-2">
          <div class="w-2 h-2 rounded-full bg-blue-500"></div>
          <span class="text-xs font-bold uppercase tracking-widest">日本語 (Japanese)</span>
        </div>
        <div class="flex-1 bg-white border border-gray-100 rounded-3xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-shadow duration-300 min-h-[400px] flex flex-col relative overflow-hidden group">
          <div class="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
            <MessageSquare class="w-24 h-24 text-blue-500" />
          </div>
          <p class="text-2xl leading-relaxed text-gray-700 font-medium overflow-y-auto z-10 whitespace-pre-wrap">
            {{ store.japaneseText || '話し始めると、ここに翻訳が表示されます...' }}
          </p>
        </div>
      </section>

    </main>

    <footer class="py-6 flex flex-col items-center gap-1">
      <div class="text-gray-400 text-sm font-medium">Powered by Google Gemini 1.5 Flash</div>
      <div class="text-gray-300 text-[10px] uppercase tracking-tighter">Last Updated: 2026-01-14 12:22:00 (修復ScriptProcessor)</div>
    </footer>
  </div>
</template>

<style>
@import "https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css";

body {
  margin: 0;
  background-color: #f9fafb; /* gray-50 */
}
</style>
