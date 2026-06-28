"""
sfx_configurator.py — 効果音割り当てコンフィギュレーター
イベント別の効果音を一覧表示・試聴・差し替えして sfx_config.json に保存する。
"""

import json
import os
import threading
import tkinter as tk
from tkinter import messagebox

pygame = None
HAS_PYGAME = False
try:
    import pygame as _pygame
    _pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
    pygame = _pygame
    HAS_PYGAME = True
except ImportError:
    pass

_HERE      = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.dirname(os.path.dirname(_HERE))
_SND_ROOT  = os.path.join(_REPO_ROOT, "assets", "sounds")
_CFG_PATH  = os.path.join(_SND_ROOT, "sfx_config.json")
_DB_PATH   = os.path.join(_SND_ROOT, "sfx_db.json")

CATEGORY_LABELS = {
    "shoot":       "shoot　　　通常弾　発射",
    "laser_shoot": "laser_shoot　レーザー発射",
    "hit":         "hit　　　　被弾",
    "wall_hit":    "wall_hit　　壁 衝突",
    "death":       "death　　　死亡",
    "dry_fire":    "dry_fire　　弾切れ",
    "powerup":     "powerup　　パワーアップ",
    "countdown":   "countdown　カウントダウン",
    "win":         "win　　　　ラウンド勝利",
    "lose":        "lose　　　　ラウンド敗北",
}

def res_to_abs(res_path: str) -> str:
    rel = res_path.removeprefix("res://")
    return os.path.join(_REPO_ROOT, rel.replace("/", os.sep))

def abs_to_res(abs_path: str) -> str:
    rel = os.path.relpath(abs_path, _REPO_ROOT).replace("\\", "/")
    return "res://" + rel

def abs_to_rel_snd(abs_path: str) -> str:
    return os.path.relpath(abs_path, _SND_ROOT)

def play_file(path: str):
    if not HAS_PYGAME or pygame is None:
        return
    _pg = pygame
    def _play():
        try:
            _pg.mixer.music.load(path)
            _pg.mixer.music.play()
        except Exception:
            pass
    threading.Thread(target=_play, daemon=True).start()


class SfxConfigurator:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("SFX Configurator — 効果音割り当てツール")
        self.root.geometry("1150x700")
        self.root.configure(bg="#1a1a2e")

        self.cfg: dict  = {}   # カテゴリ → [{"id":..., "path":...}, ...]
        self.db: dict   = {}   # abs_path → {"filename":..., "tags":[], "memo":""}
        self.sel_cat: str = "" # 選択中カテゴリ

        self._load_cfg()
        self._load_db()
        self._build_ui()

    # ── データ読み込み ────────────────────────────────────────────────
    def _load_cfg(self):
        if os.path.exists(_CFG_PATH):
            with open(_CFG_PATH, encoding="utf-8") as f:
                self.cfg = json.load(f)
        else:
            self.cfg = {cat: [] for cat in CATEGORY_LABELS}

    def _load_db(self):
        if os.path.exists(_DB_PATH):
            with open(_DB_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            # キーを小文字・スラッシュ統一で正規化
            self.db = {k.replace("\\", "/"): v for k, v in raw.items()}
        else:
            self.db = {}

    def _db_entry(self, abs_path: str) -> dict:
        key = abs_path.replace("\\", "/")
        return self.db.get(key, {})

    # ── UI構築 ────────────────────────────────────────────────────────
    def _build_ui(self):
        # 上部バー
        bar = tk.Frame(self.root, bg="#16213e", pady=6)
        bar.pack(fill="x")
        tk.Label(bar, text="SFX Configurator", bg="#16213e", fg="#00d4ff",
                 font=("Yu Gothic UI", 13, "bold")).pack(side="left", padx=12)
        tk.Button(bar, text="💾 sfx_config.json を保存", command=self._save,
                  bg="#0a5c4a", fg="white", relief="flat", padx=12, pady=4
                  ).pack(side="right", padx=8)
        self._saved_lbl = tk.Label(bar, text="", bg="#16213e", fg="#00ff99",
                                   font=("Yu Gothic UI", 9))
        self._saved_lbl.pack(side="right")

        # 3カラムレイアウト
        body = tk.Frame(self.root, bg="#1a1a2e")
        body.pack(fill="both", expand=True, padx=8, pady=(0, 8))

        # 左：カテゴリ
        left = tk.Frame(body, bg="#16213e", width=220)
        left.pack(side="left", fill="y", padx=(0, 4))
        left.pack_propagate(False)

        tk.Label(left, text="イベント", bg="#16213e", fg="#aaaaaa",
                 font=("Yu Gothic UI", 10, "bold"), pady=6).pack(fill="x")

        self._cat_list = tk.Listbox(left, bg="#0d1b2a", fg="#cccccc",
                                    selectbackground="#e94560", selectforeground="white",
                                    activestyle="none", relief="flat",
                                    font=("Yu Gothic UI", 10), bd=0)
        self._cat_list.pack(fill="both", expand=True, padx=4, pady=4)
        for cat in CATEGORY_LABELS:
            self._cat_list.insert("end", CATEGORY_LABELS[cat])
        self._cat_list.bind("<<ListboxSelect>>", self._on_cat_select)

        # 中：割り当て済み音
        mid = tk.Frame(body, bg="#1a1a2e")
        mid.pack(side="left", fill="both", expand=True, padx=(0, 4))

        tk.Label(mid, text="現在の割り当て音 (ID・試聴・削除)",
                 bg="#1a1a2e", fg="#aaaaaa",
                 font=("Yu Gothic UI", 10, "bold"), pady=6, anchor="w").pack(fill="x")

        self._mid_frame = tk.Frame(mid, bg="#1a1a2e")
        self._mid_frame.pack(fill="both", expand=True)
        self._build_mid_empty()

        # 右：候補音（sfx_db）
        right = tk.Frame(body, bg="#16213e", width=340)
        right.pack(side="right", fill="y", padx=(4, 0))
        right.pack_propagate(False)

        tk.Label(right, text="sfx_db 候補音", bg="#16213e", fg="#aaaaaa",
                 font=("Yu Gothic UI", 10, "bold"), pady=6).pack(fill="x")

        # タグフィルタ
        filt_row = tk.Frame(right, bg="#16213e")
        filt_row.pack(fill="x", padx=6)
        tk.Label(filt_row, text="タグ:", bg="#16213e", fg="#888888",
                 font=("Yu Gothic UI", 9)).pack(side="left")
        self._tag_filter = tk.StringVar(value="")
        self._tag_filter.trace_add("write", lambda *_: self._refresh_db_list())
        tag_entry = tk.Entry(filt_row, textvariable=self._tag_filter,
                             bg="#0f3460", fg="white", insertbackground="white",
                             relief="flat", bd=4, width=12)
        tag_entry.pack(side="left", padx=4)
        tk.Button(filt_row, text="✕", command=lambda: self._tag_filter.set(""),
                  bg="#16213e", fg="#888888", relief="flat", padx=2).pack(side="left")

        db_frame = tk.Frame(right, bg="#16213e")
        db_frame.pack(fill="both", expand=True, padx=4, pady=4)

        sb = tk.Scrollbar(db_frame, orient="vertical", bg="#0f3460")
        sb.pack(side="right", fill="y")
        self._db_list = tk.Listbox(db_frame, yscrollcommand=sb.set,
                                   bg="#0d1b2a", fg="#cccccc",
                                   selectbackground="#0a5c4a", selectforeground="white",
                                   activestyle="none", relief="flat",
                                   font=("Yu Gothic UI", 9), bd=0)
        self._db_list.pack(fill="both", expand=True)
        sb.config(command=self._db_list.yview)
        self._db_entries: list[str] = []  # abs_path 順

        btn_row = tk.Frame(right, bg="#16213e")
        btn_row.pack(fill="x", padx=6, pady=4)
        tk.Button(btn_row, text="▶ 試聴", command=self._play_db_sel,
                  bg="#333355", fg="white", relief="flat", padx=8).pack(side="left")
        tk.Button(btn_row, text="← 割り当てに追加", command=self._add_from_db,
                  bg="#0f3460", fg="white", relief="flat", padx=8).pack(side="left", padx=4)

        self._db_memo = tk.Label(right, text="", bg="#16213e", fg="#aaaaaa",
                                 font=("Yu Gothic UI", 8), wraplength=300,
                                 justify="left", anchor="w", padx=6, pady=4)
        self._db_memo.pack(fill="x")

        self._db_list.bind("<<ListboxSelect>>", self._on_db_sel)
        self._refresh_db_list()

        # 最初のカテゴリを選択
        self._cat_list.selection_set(0)
        self._on_cat_select()

    def _build_mid_empty(self):
        for w in self._mid_frame.winfo_children():
            w.destroy()
        tk.Label(self._mid_frame, text="← カテゴリを選択", bg="#1a1a2e",
                 fg="#555555", font=("Yu Gothic UI", 11)).pack(expand=True)

    # ── カテゴリ選択 ────────────────────────────────────────────────
    def _on_cat_select(self, _=None):
        sel = self._cat_list.curselection()
        if not sel:
            return
        cats = list(CATEGORY_LABELS.keys())
        self.sel_cat = cats[sel[0]]
        self._rebuild_mid()

    def _rebuild_mid(self):
        for w in self._mid_frame.winfo_children():
            w.destroy()
        if not self.sel_cat:
            return
        entries = self.cfg.get(self.sel_cat, [])
        if not entries:
            tk.Label(self._mid_frame, text="（音が割り当てられていません）",
                     bg="#1a1a2e", fg="#555555").pack(expand=True)
            return

        # ヘッダー
        hdr = tk.Frame(self._mid_frame, bg="#16213e")
        hdr.pack(fill="x", pady=(0, 2))
        for text, w in [("ID", 130), ("ファイル名", 240), ("メモ", 200), ("", 90)]:
            tk.Label(hdr, text=text, bg="#16213e", fg="#666666",
                     font=("Yu Gothic UI", 8), width=0,
                     anchor="w").pack(side="left", padx=4)

        sb_frame = tk.Frame(self._mid_frame, bg="#1a1a2e")
        sb_frame.pack(fill="both", expand=True)
        canvas = tk.Canvas(sb_frame, bg="#1a1a2e", highlightthickness=0)
        vsb = tk.Scrollbar(sb_frame, orient="vertical", command=canvas.yview)
        canvas.configure(yscrollcommand=vsb.set)
        vsb.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True)

        inner = tk.Frame(canvas, bg="#1a1a2e")
        canvas.create_window((0, 0), window=inner, anchor="nw")
        inner.bind("<Configure>", lambda _: canvas.configure(
            scrollregion=canvas.bbox("all")))

        for idx, entry in enumerate(entries):
            self._make_entry_row(inner, idx, entry)

    def _make_entry_row(self, parent: tk.Frame, idx: int, entry: dict):
        eid    = entry["id"]
        res_p  = entry["path"]
        abs_p  = res_to_abs(res_p)
        db_e   = self._db_entry(abs_p)
        memo   = db_e.get("memo", "")
        fname  = os.path.basename(abs_p)

        row = tk.Frame(parent, bg="#0d1b2a" if idx % 2 == 0 else "#111122")
        row.pack(fill="x", pady=1)

        # ID（コピーしやすいようにLabelではなくEntry readonly）
        id_var = tk.StringVar(value=eid)
        id_e = tk.Entry(row, textvariable=id_var, state="readonly",
                        readonlybackground="#0f3460", fg="#00d4ff",
                        relief="flat", font=("Yu Gothic UI", 9), width=16)
        id_e.pack(side="left", padx=4, pady=2)

        tk.Label(row, text=fname, bg=row["bg"], fg="#cccccc",
                 font=("Yu Gothic UI", 9), width=28, anchor="w").pack(side="left")
        tk.Label(row, text=memo[:28] + ("…" if len(memo) > 28 else ""),
                 bg=row["bg"], fg="#888888",
                 font=("Yu Gothic UI", 8), width=24, anchor="w").pack(side="left")

        tk.Button(row, text="▶", command=lambda p=abs_p: play_file(p),
                  bg="#333355", fg="white", relief="flat", padx=6, pady=1
                  ).pack(side="left", padx=2)
        tk.Button(row, text="✕ 削除", command=lambda i=idx: self._remove_entry(i),
                  bg="#5c1a1a", fg="#ffaaaa", relief="flat", padx=6, pady=1
                  ).pack(side="left", padx=2)

    # ── DB候補パネル ────────────────────────────────────────────────
    def _refresh_db_list(self):
        self._db_list.delete(0, "end")
        self._db_entries = []
        tag_q = self._tag_filter.get().strip().lower()
        for abs_key, entry in self.db.items():
            # abs_key はバックスラッシュ統一済み
            tags = [t.lower() for t in entry.get("tags", [])]
            if tag_q and tag_q not in tags and tag_q not in entry.get("memo", "").lower():
                continue
            fname = os.path.basename(abs_key.replace("/", os.sep))
            memo  = entry.get("memo", "")
            tag_str = " ".join(f"[{t}]" for t in entry.get("tags", []))
            display = f"{fname}  {tag_str}  {memo[:20]}"
            self._db_list.insert("end", display)
            self._db_entries.append(abs_key)

    def _on_db_sel(self, _=None):
        sel = self._db_list.curselection()
        if not sel:
            self._db_memo.config(text="")
            return
        abs_key = self._db_entries[sel[0]]
        entry = self.db.get(abs_key, {})
        memo  = entry.get("memo", "")
        tags  = ", ".join(entry.get("tags", []))
        self._db_memo.config(text=f"タグ: {tags}\nメモ: {memo}")

    def _play_db_sel(self):
        sel = self._db_list.curselection()
        if not sel:
            return
        abs_key = self._db_entries[sel[0]]
        play_file(abs_key.replace("/", os.sep))

    def _add_from_db(self):
        if not self.sel_cat:
            messagebox.showinfo("", "左のカテゴリを選んでください")
            return
        sel = self._db_list.curselection()
        if not sel:
            return
        abs_key = self._db_entries[sel[0]]
        res_p   = abs_to_res(abs_key.replace("/", os.sep))
        entries = self.cfg.setdefault(self.sel_cat, [])
        # 重複チェック
        if any(e["path"] == res_p for e in entries):
            messagebox.showinfo("", "既に追加されています")
            return
        n   = len(entries) + 1
        eid = f"{self.sel_cat}_{n}"
        entries.append({"id": eid, "path": res_p})
        self._rebuild_mid()

    # ── 削除 ────────────────────────────────────────────────────────
    def _remove_entry(self, idx: int):
        entries = self.cfg.get(self.sel_cat, [])
        if 0 <= idx < len(entries):
            entries.pop(idx)
            # ID を振り直し
            for i, e in enumerate(entries):
                e["id"] = f"{self.sel_cat}_{i+1}"
            self._rebuild_mid()

    # ── 保存 ────────────────────────────────────────────────────────
    def _save(self):
        with open(_CFG_PATH, "w", encoding="utf-8") as f:
            json.dump(self.cfg, f, ensure_ascii=False, indent=2)
        self._saved_lbl.config(text="✓ 保存しました")
        self.root.after(2000, lambda: self._saved_lbl.config(text=""))


def main():
    root = tk.Tk()
    SfxConfigurator(root)
    root.mainloop()


if __name__ == "__main__":
    main()
