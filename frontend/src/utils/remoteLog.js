// 遠端 LOG 工具
const REMOTE_LOG_ENABLED = true;
const LOG_API = '/api/log';

async function sendLog(level, message, data = {}) {
    if (!REMOTE_LOG_ENABLED) return;

    try {
        await fetch(LOG_API, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ level, message, data })
        });
    } catch (e) {
        // 靜默失敗，避免影響主程式
    }
}

// 覆寫 console 方法
const originalLog = console.log;
const originalError = console.error;
const originalWarn = console.warn;

console.log = function (...args) {
    originalLog.apply(console, args);
    const message = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
    sendLog('info', message);
};

console.error = function (...args) {
    originalError.apply(console, args);
    const message = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
    sendLog('error', message);
};

console.warn = function (...args) {
    originalWarn.apply(console, args);
    const message = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
    sendLog('warn', message);
};

export { sendLog };
