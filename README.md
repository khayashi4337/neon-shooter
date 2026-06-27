# Neon Shooter

ネオン・サイバーパンク風の2Dトップダウン対戦シューティングゲーム。  
オンラインでリアルタイム2人対戦。負けた側がパワーアップを選んで逆転を狙う。

---

## 必要なもの

- [Godot 4.6以上](https://godotengine.org/download/)
- [ngrok](https://ngrok.com/)（インターネット越しに対戦する場合）

---

## 起動方法

### 1. Godotエディタで起動（開発・テスト用）

```
godot project.godot
```

またはGodotエディタの「Import」からこのフォルダを選択して開き、**F5**で実行。

### 2. EXEで起動（配布版）

`Releases` からEXEをダウンロードしてダブルクリック。

---

## オンライン対戦の接続方法

### ホスト側（サーバーを立てる人）

1. ゲームを起動
2. **HOST GAME** をクリック
3. 数秒後に `wss://xxxx.ngrok-free.app` 形式のURLが画面に表示される
4. 「コピー」ボタンでURLをコピーし、相手にLINE・Discord等で送る

### ゲスト側（参加する人）

1. ゲームを起動
2. ホストから受け取ったURLをURL欄に貼り付け
3. **JOIN GAME** をクリック

---

## ローカルテスト（同じPC・同じLANで確認する場合）

Godotエディタのメニューから **Debug → Run Multiple Instances → 2 Instances** を選択してF5。  
2つのウィンドウが開くので、一方でHOST、もう一方でIP `ws://127.0.0.1:7777` でJOIN。

---

## 操作方法

| 操作 | キー |
|------|------|
| 移動 | WASD または 矢印キー |
| 照準 | マウス移動 |
| 射撃 | マウス左クリック（長押しで連射） |

---

## ゲームルール

- **3ラウンド先取**で勝利
- 相手のHPをゼロにするとラウンド勝利
- **負けた側がパワーアップを1つ選べる**（逆転要素）

### パワーアップ一覧

| 名前 | 効果 |
|------|------|
| SPEED | 移動速度 +50% |
| RAPID | 連射速度 2倍 |
| ARMOR | 最大HP +50% |
| PIERCE | 弾が壁を貫通 |

パワーアップは累積。何度も負けるほど強くなる。

---

## EXEのダウンロード方法（プレイヤー向け）

1. このページ右側の **[Releases](https://github.com/khayashi4337/neon-shooter/releases)** をクリック
2. 最新バージョンの `neon-shooter.exe` をダウンロード
3. ダブルクリックで起動

---

## EXEのエクスポートとリリース方法（開発者向け）

### ステップ1：エクスポートテンプレートのインストール（初回のみ）

1. Godotエディタを開く
2. メニューの `Editor → Manage Export Templates...`
3. `Download and Install` をクリック（数分かかる）

### ステップ2：EXEをエクスポート

1. Godotエディタのメニューから `Project → Export`
2. `Add Preset` → **Windows Desktop** を選択
3. 出力パスを `export/neon-shooter.exe` に設定
4. **Export Project** をクリック

またはコマンドラインで：

```
mkdir export
godot --headless --export-release "Windows Desktop" export/neon-shooter.exe
```

### ステップ3：GitHub Releasesにアップロード

バージョン番号を決めて（例：v0.1.0）、以下のコマンドを実行：

```
gh release create v0.1.0 export/neon-shooter.exe \
  --title "Neon Shooter v0.1.0" \
  --notes "最初のリリース"
```

これで https://github.com/khayashi4337/neon-shooter/releases にEXEが公開される。

---

## 技術構成

| 項目 | 内容 |
|------|------|
| エンジン | Godot 4.6 |
| 通信 | WebSocketMultiplayerPeer |
| トンネル | ngrok HTTP |
| 言語 | GDScript |
