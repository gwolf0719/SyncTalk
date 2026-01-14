<script setup>
import { useTranslationStore } from './stores/translation';
import { useGeminiLive } from './composables/useGeminiLive';
import { Mic, MicOff, Languages, MessageSquare } from 'lucide-vue-next';

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
  <div class="min-h-screen bg-slate-900 text-slate-100 font-sans p-6 flex flex-col items-center">
    <header class="w-full max-w-4xl flex justify-between items-center mb-12">
      <div class="flex items-center gap-3">
        <div class="bg-indigo-600 p-2 rounded-lg">
          <Languages class="w-8 h-8 text-white" />
        </div>
        <h1 class="text-3xl font-bold tracking-tight">SyncTalk</h1>
      </div>
      
      <button 
        @click="toggleConnection"
        :disabled="store.isConnecting"
        class="group relative flex items-center gap-2 px-6 py-3 rounded-full font-semibold transition-all duration-300 overflow-hidden"
        :class="store.isConnected ? 'bg-red-500/10 text-red-400 border border-red-500/50 hover:bg-red-500/20' : 'bg-indigo-600 text-white hover:bg-indigo-700 shadow-lg shadow-indigo-500/20'"
      >
        <span v-if="store.isConnecting" class="animate-spin rounded-full h-5 w-5 border-2 border-white/30 border-t-white"></span>
        <template v-else>
          <Mic v-if="!store.isConnected" class="w-5 h-5" />
          <MicOff v-else class="w-5 h-5" />
          {{ store.isConnected ? '斷開連線' : '開始通話' }}
        </template>
      </button>
    </header>

    <main class="w-full max-w-4xl grid grid-cols-1 md:grid-cols-2 gap-8 flex-1">
      <!-- Chinese Section -->
      <section class="flex flex-col gap-4">
        <div class="flex items-center gap-2 text-slate-400 mb-2">
          <MessageSquare class="w-4 h-4" />
          <span class="text-sm font-medium uppercase tracking-wider">中文</span>
        </div>
        <div class="flex-1 bg-slate-800/50 border border-slate-700/50 rounded-2xl p-8 backdrop-blur-sm min-h-[300px] flex flex-col shadow-xl">
          <p class="text-2xl leading-relaxed text-indigo-100 overflow-y-auto">
            {{ store.chineseText || '等待語音輸入...' }}
          </p>
          <div v-if="store.isConnected" class="mt-auto h-1 bg-slate-700 rounded-full overflow-hidden">
            <div 
              class="h-full bg-indigo-500 transition-all duration-75"
              :style="{ width: (store.volume * 100) + '%' }"
            ></div>
          </div>
        </div>
      </section>

      <!-- Japanese Section -->
      <section class="flex flex-col gap-4">
        <div class="flex items-center gap-2 text-slate-400 mb-2">
          <MessageSquare class="w-4 h-4" />
          <span class="text-sm font-medium uppercase tracking-wider">日本語</span>
        </div>
        <div class="flex-1 bg-indigo-500/10 border border-indigo-500/20 rounded-2xl p-8 backdrop-blur-sm min-h-[300px] flex flex-col shadow-xl">
          <p class="text-2xl leading-relaxed text-indigo-400 overflow-y-auto font-medium">
            {{ store.japaneseText || '音声入力を待っています...' }}
          </p>
        </div>
      </section>
    </main>

    <footer class="mt-12 text-slate-500 text-sm">
      <p v-if="store.errorMessage" class="text-red-400 bg-red-400/10 px-4 py-2 rounded-lg border border-red-400/20 mb-4 animate-pulse">
        {{ store.errorMessage }}
      </p>
      Gemini 1.5 Flash 即時多模態翻譯 · 純網頁架構
    </footer>
  </div>
</template>

<style>
@import "https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css";

body {
  margin: 0;
  background-color: #0f172a;
}
</style>
