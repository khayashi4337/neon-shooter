"""
sfx_tagger.py — 効果音タグ付けツール
音ファイルを聴いて「雰囲気メモ」と「用途タグ」を付けて sfx_db.json に保存する。
"""

import json
import os
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

try:
    import pygame
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
    HAS_PYGAME = True
except ImportError:
    HAS_PYGAME = False

AUDIO_EXTS = {".ogg", ".wav", ".mp3", ".flac"}

# sfx_tagger.py → tools/sfx_tagger/ → tools/ → neon-shooter/ → assets/sounds/
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DEFAULT_SOUNDS_DIR = os.path.join(_REPO_ROOT, "assets", "sounds")

TAG_DEFS = [
    ("weapon",  "武器 / 射撃"),
    ("laser",   "レーザー"),
    ("shield",  "シールド / 防御"),
    ("death",   "死亡 / やられ"),
    ("hit",     "被弾 / 衝撃"),
    ("ui",      "UI / メニュー"),
    ("ambient", "環境音 / BGM"),
    ("powerup", "パワーアップ"),
    ("other",   "その他"),
]

DB_FILENAME = "sfx_db.json"


def find_audio_files(root: str) -> list[str]:
    result = []
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if os.path.splitext(f)[1].lower() in AUDIO_EXTS:
                result.append(os.path.join(dirpath, f))
    return result


class SfxTagger:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("SFX Tagger — 効果音タグ付けツール")
        self.root.geometry("1000x680")
        self.root.configure(bg="#1a1a2e")

        self.scan_dir: str = ""
        self.db_path: str = ""
        self.db: dict = {}          # path → {"memo": str, "tags": [str]}
        self.audio_files: list[str] = []
        self.current_file: str = ""
        self._play_lock = threading.Lock()

        self._build_ui()
        self._apply_theme()

    # ── UI構築 ───────────────────────────────────────────────────────────
    def _build_ui(self):
        # ── 上部ツールバー
        bar = tk.Frame(self.root, bg="#16213e", pady=6)
        bar.pack(fill="x")

        tk.Button(bar, text="📂 フォルダを開く", command=self._open_dir,
                  bg="#0f3460", fg="white", relief="flat",
                  padx=12, pady=4).pack(side="left", padx=8)

        self._dir_lbl = tk.Label(bar, text="（フォルダ未選択）",
                                 bg="#16213e", fg="#aaaaaa", anchor="w")
        self._dir_lbl.pack(side="left", fill="x", expand=True)

        self._save_btn = tk.Button(bar, text="💾 保存", command=self._save_entry,
                                   bg="#0a5c4a", fg="white", relief="flat",
                                   padx=12, pady=4, state="disabled")
        self._save_btn.pack(side="right", padx=8)

        # ── メイン分割
        pane = tk.PanedWindow(self.root, orient="horizontal", bg="#1a1a2e",
                              sashwidth=4, sashrelief="flat")
        pane.pack(fill="both", expand=True, padx=8, pady=(0, 8))

        # 左：ファイルリスト
        left = tk.Frame(pane, bg="#16213e")
        pane.add(left, minsize=300)

        tk.Label(left, text="音ファイル一覧", bg="#16213e",
                 fg="#00d4ff", font=("Yu Gothic UI", 11, "bold"),
                 anchor="w", padx=8, pady=6).pack(fill="x")

        self._filter_var = tk.StringVar()
        self._filter_var.trace_add("write", self._on_filter)
        filter_entry = tk.Entry(left, textvariable=self._filter_var,
                                bg="#0f3460", fg="white", insertbackground="white",
                                relief="flat", bd=6)
        filter_entry.pack(fill="x", padx=6, pady=(0, 4))
        tk.Label(left, text="🔍 絞り込み", bg="#16213e", fg="#888888",
                 font=("Yu Gothic UI", 8)).place(in_=filter_entry, relx=1.0, rely=0.5,
                                                  anchor="e", x=-6)

        list_frame = tk.Frame(left, bg="#16213e")
        list_frame.pack(fill="both", expand=True)

        scrollbar = tk.Scrollbar(list_frame, orient="vertical", bg="#0f3460")
        scrollbar.pack(side="right", fill="y")

        self._listbox = tk.Listbox(
            list_frame,
            yscrollcommand=scrollbar.set,
            bg="#0d1b2a", fg="#cccccc",
            selectbackground="#e94560", selectforeground="white",
            activestyle="none", relief="flat",
            font=("Yu Gothic UI", 9),
        )
        self._listbox.pack(fill="both", expand=True)
        scrollbar.config(command=self._listbox.yview)
        self._listbox.bind("<<ListboxSelect>>", self._on_select)
        self._listbox.bind("<Double-Button-1>", self._on_play)

        # 再生ボタン
        btn_row = tk.Frame(left, bg="#16213e")
        btn_row.pack(fill="x", padx=6, pady=4)
        self._play_btn = tk.Button(btn_row, text="▶ 再生",
                                   command=self._on_play,
                                   bg="#e94560", fg="white", relief="flat",
                                   padx=10, pady=4, state="disabled")
        self._play_btn.pack(side="left")
        self._stop_btn = tk.Button(btn_row, text="■ 停止",
                                   command=self._stop_sound,
                                   bg="#333355", fg="white", relief="flat",
                                   padx=10, pady=4, state="disabled")
        self._stop_btn.pack(side="left", padx=4)

        self._status_lbl = tk.Label(left, text="", bg="#16213e",
                                    fg="#888888", font=("Yu Gothic UI", 8), anchor="w")
        self._status_lbl.pack(fill="x", padx=8)

        # 右：入力パネル
        right = tk.Frame(pane, bg="#1a1a2e", padx=16, pady=12)
        pane.add(right, minsize=400)

        # ファイル名表示
        self._file_lbl = tk.Label(right, text="（ファイル未選択）",
                                  bg="#1a1a2e", fg="#00d4ff",
                                  font=("Yu Gothic UI", 11, "bold"),
                                  anchor="w", wraplength=540)
        self._file_lbl.pack(fill="x", pady=(0, 12))

        # ── タグ
        tag_frame = tk.LabelFrame(right, text="用途タグ",
                                   bg="#1a1a2e", fg="#aaaaaa",
                                   font=("Yu Gothic UI", 9),
                                   relief="groove", bd=1, padx=10, pady=8)
        tag_frame.pack(fill="x", pady=(0, 12))

        self._tag_vars: dict[str, tk.BooleanVar] = {}
        cols = 3
        for i, (key, label) in enumerate(TAG_DEFS):
            var = tk.BooleanVar()
            self._tag_vars[key] = var
            cb = tk.Checkbutton(
                tag_frame, text=label, variable=var,
                bg="#1a1a2e", fg="#cccccc",
                selectcolor="#0f3460", activebackground="#1a1a2e",
                activeforeground="white",
                font=("Yu Gothic UI", 10),
            )
            cb.grid(row=i // cols, column=i % cols, sticky="w", padx=10, pady=2)

        # ── 雰囲気メモ
        memo_frame = tk.LabelFrame(right, text="雰囲気メモ（自由記述）",
                                    bg="#1a1a2e", fg="#aaaaaa",
                                    font=("Yu Gothic UI", 9),
                                    relief="groove", bd=1, padx=10, pady=8)
        memo_frame.pack(fill="both", expand=True, pady=(0, 12))

        self._memo_text = tk.Text(
            memo_frame,
            bg="#0d1b2a", fg="#cccccc", insertbackground="white",
            relief="flat", wrap="word",
            font=("Yu Gothic UI", 10),
            padx=8, pady=8,
        )
        self._memo_text.pack(fill="both", expand=True)

        # ── 保存済みバッジ
        badge_row = tk.Frame(right, bg="#1a1a2e")
        badge_row.pack(fill="x")
        self._saved_lbl = tk.Label(badge_row, text="", bg="#1a1a2e",
                                   fg="#00ff99", font=("Yu Gothic UI", 9))
        self._saved_lbl.pack(side="left")

        # ── 統計バー（下部）
        self._stat_lbl = tk.Label(self.root,
                                  text="ファイル数: 0 ／ 登録済み: 0",
                                  bg="#0d1117", fg="#666666",
                                  font=("Yu Gothic UI", 8),
                                  anchor="w", padx=8)
        self._stat_lbl.pack(fill="x")

    def _apply_theme(self):
        style = ttk.Style()
        style.theme_use("clam")

    # ── ディレクトリ選択 ─────────────────────────────────────────────────
    def _open_dir(self):
        initial = _DEFAULT_SOUNDS_DIR if os.path.exists(_DEFAULT_SOUNDS_DIR) else os.path.expanduser("~")
        d = filedialog.askdirectory(title="音ファイルが入ったフォルダを選択", initialdir=initial)
        if not d:
            return
        self.scan_dir = d
        self.db_path = os.path.join(d, DB_FILENAME)
        self._dir_lbl.config(text=d)
        self._load_db()
        self._scan_files()

    def _scan_files(self):
        self.audio_files = find_audio_files(self.scan_dir)
        self._refresh_list()
        self._update_stat()

    def _refresh_list(self, filter_text: str = ""):
        self._listbox.delete(0, "end")
        q = filter_text.lower()
        for path in self.audio_files:
            name = os.path.relpath(path, self.scan_dir)
            if q and q not in name.lower():
                continue
            # 登録済みは ✓ マーク
            prefix = "✓ " if path in self.db else "  "
            self._listbox.insert("end", prefix + name)

    def _on_filter(self, *_):
        self._refresh_list(self._filter_var.get())

    # ── ファイル選択 ─────────────────────────────────────────────────────
    def _on_select(self, _event=None):
        sel = self._listbox.curselection()
        if not sel:
            return
        raw = self._listbox.get(sel[0])
        # 先頭の "✓ " or "  " を除去
        relpath = raw[2:]
        self.current_file = os.path.join(self.scan_dir, relpath)
        self._file_lbl.config(text=os.path.basename(self.current_file))
        self._load_entry()
        self._play_btn.config(state="normal")
        self._stop_btn.config(state="normal")
        self._save_btn.config(state="normal")

    # ── 再生 ─────────────────────────────────────────────────────────────
    def _on_play(self, _event=None):
        if not self.current_file:
            return
        if not HAS_PYGAME:
            messagebox.showwarning("再生不可",
                                   "pygame がインストールされていません。\n"
                                   "pip install pygame で導入してください。")
            return
        threading.Thread(target=self._play_sound,
                         args=(self.current_file,), daemon=True).start()

    def _play_sound(self, path: str):
        with self._play_lock:
            try:
                pygame.mixer.music.load(path)
                pygame.mixer.music.play()
                self._status("▶ 再生中: " + os.path.basename(path))
            except Exception as e:
                self._status("再生エラー: " + str(e))

    def _stop_sound(self):
        if HAS_PYGAME:
            pygame.mixer.music.stop()
        self._status("■ 停止")

    def _status(self, msg: str):
        self.root.after(0, lambda: self._status_lbl.config(text=msg))

    # ── DB 読み書き ───────────────────────────────────────────────────────
    def _load_db(self):
        if os.path.exists(self.db_path):
            with open(self.db_path, encoding="utf-8") as f:
                self.db = json.load(f)
        else:
            self.db = {}

    def _save_db(self):
        with open(self.db_path, "w", encoding="utf-8") as f:
            json.dump(self.db, f, ensure_ascii=False, indent=2)

    def _load_entry(self):
        entry = self.db.get(self.current_file, {})
        # タグ
        saved_tags = set(entry.get("tags", []))
        for key, var in self._tag_vars.items():
            var.set(key in saved_tags)
        # メモ
        self._memo_text.delete("1.0", "end")
        self._memo_text.insert("1.0", entry.get("memo", ""))
        # バッジ
        if self.current_file in self.db:
            self._saved_lbl.config(text="✓ 登録済み")
        else:
            self._saved_lbl.config(text="")

    def _save_entry(self):
        if not self.current_file:
            return
        tags = [key for key, var in self._tag_vars.items() if var.get()]
        memo = self._memo_text.get("1.0", "end").strip()
        self.db[self.current_file] = {
            "filename": os.path.relpath(self.current_file, self.scan_dir),
            "tags": tags,
            "memo": memo,
        }
        self._save_db()
        self._saved_lbl.config(text="✓ 保存しました")
        self._refresh_list(self._filter_var.get())
        self._update_stat()

    def _update_stat(self):
        total = len(self.audio_files)
        done = len(self.db)
        self._stat_lbl.config(
            text=f"ファイル数: {total} ／ 登録済み: {done} ／ 未登録: {total - done}")


def main():
    root = tk.Tk()
    app = SfxTagger(root)
    root.mainloop()


if __name__ == "__main__":
    main()
