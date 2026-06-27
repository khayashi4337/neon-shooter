# -*- coding: utf-8 -*-
"""
ngrokフロー単体テスト
ngrokプロセスを全終了 -> 新規起動 -> URLを取得する一連の流れを2回検証する
使い方: python tests/test_ngrok.py
"""

import io
import json
import subprocess
import sys
import time
import urllib.request

# Windows cp932対策：標準出力をUTF-8に固定
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

NGROK_API    = "http://localhost:4040/api/tunnels"
NGROK_PORT   = 7777
WAIT_STARTUP = 5.0   # 起動後の初回待機（秒）
POLL_INTERVAL = 1.0
POLL_MAX      = 20   # 最大20秒ポーリング


def kill_ngrok():
    result = subprocess.run(
        ["taskkill", "/F", "/IM", "ngrok.exe"],
        capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    killed = "SUCCESS" in result.stdout or "成功" in result.stdout
    print("  [OK] 既存ngrokプロセスを終了" if killed else "  [--] ngrokプロセスなし")
    time.sleep(0.8)


def start_ngrok():
    # Windows: cmd /c start /B でバックグラウンド起動
    if sys.platform == "win32":
        proc = subprocess.Popen(
            ["cmd", "/c", "start", "/B", "ngrok", "http", str(NGROK_PORT)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        proc = subprocess.Popen(
            ["ngrok", "http", str(NGROK_PORT)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    print(f"  [OK] ngrok起動コマンド発行 (PID: {proc.pid})")
    return proc


def fetch_url():
    print(f"  起動待機 {WAIT_STARTUP}秒...")
    time.sleep(WAIT_STARTUP)

    for i in range(1, POLL_MAX + 1):
        try:
            with urllib.request.urlopen(NGROK_API, timeout=2) as resp:
                data = json.loads(resp.read())
                tunnels = data.get("tunnels", [])
                if tunnels:
                    public_url = tunnels[0]["public_url"]
                    ws_url = "wss://" + public_url.replace("https://", "")
                    return ws_url
                print(f"  [{i:02d}/{POLL_MAX}] トンネル確立待ち...")
        except Exception as e:
            print(f"  [{i:02d}/{POLL_MAX}] API応答なし: {e}")
        time.sleep(POLL_INTERVAL)
    return None


def run_test(n):
    sep = "=" * 50
    print(f"\n{sep}")
    print(f"  テスト {n} 回目")
    print(sep)

    print("\n[1] ngrokプロセスを全終了...")
    kill_ngrok()

    print("\n[2] ngrokを新規起動...")
    start_ngrok()

    print(f"\n[3] URLを取得中（最大 {WAIT_STARTUP + POLL_MAX}秒）...")
    url = fetch_url()

    if url:
        print(f"\n  PASS: {url}")
        return True, url
    else:
        print("\n  FAIL: URLを取得できませんでした")
        return False, None


def main():
    print("ngrokフロー単体テスト（2回連続）")

    results = []
    for i in range(1, 3):
        ok, url = run_test(i)
        results.append((ok, url))
        if i < 2:
            print("\n次のテストまで2秒待機...")
            time.sleep(2.0)

    print(f"\n{'=' * 50}")
    print("  テスト結果サマリ")
    print(f"{'=' * 50}")
    for i, (ok, url) in enumerate(results, 1):
        status = "PASS" if ok else "FAIL"
        line   = f"  テスト {i}: {status}"
        if url:
            line += f"  -> {url}"
        print(line)

    all_pass = all(ok for ok, _ in results)
    print(f"\n  総合: {'全テスト通過' if all_pass else '失敗あり'}")
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
