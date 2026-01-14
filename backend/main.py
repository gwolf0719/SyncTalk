# 遠端 LOG 收集後端
from flask import Flask, request, jsonify, send_from_directory
import os
from datetime import datetime

app = Flask(__name__, static_folder='../frontend/dist', static_url_path='')

# 儲存 LOG 的列表（簡單實現，生產環境應該用資料庫）
logs = []

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/log', methods=['POST'])
def collect_log():
    """收集前端 LOG"""
    try:
        data = request.get_json()
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'level': data.get('level', 'info'),
            'message': data.get('message', ''),
            'data': data.get('data', {})
        }
        logs.append(log_entry)
        
        # 同時輸出到 stdout，這樣會出現在 Cloud Run LOG 中
        print(f"[前端LOG] {log_entry['level'].upper()}: {log_entry['message']}", flush=True)
        if log_entry['data']:
            print(f"  數據: {log_entry['data']}", flush=True)
        
        # 只保留最近 100 條
        if len(logs) > 100:
            logs.pop(0)
        
        return jsonify({'status': 'ok'})
    except Exception as e:
        print(f"[LOG收集錯誤] {str(e)}", flush=True)
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/logs', methods=['GET'])
def get_logs():
    """取得最近的 LOG"""
    limit = request.args.get('limit', 50, type=int)
    return jsonify({'logs': logs[-limit:]})

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(app.static_folder, path)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
