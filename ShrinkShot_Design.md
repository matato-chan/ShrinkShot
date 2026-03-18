# ShrinkShot — 設計ドキュメント

## 概要

**ShrinkShot** は macOS メニューバー常駐アプリ。スクリーンショット撮影後に自動で画像を圧縮する。
Claude / ChatGPT / Slack / Notion 等に画像を貼る際のサイズ制限問題を解決する。

**ターゲット**: AI ツールに画像を頻繁に貼るユーザー（開発者・デザイナー・ライター）
**価格**: 買い切り $2.99（App Store）
**競合差別化**: CleanShot X ($29) が多機能スクショツールなのに対し、ShrinkShot は圧縮 ON/OFF に特化したシンプル＆安価なツール

---

## 技術スタック

| 項目 | 選定 |
|------|------|
| 言語 | Swift |
| UI | SwiftUI |
| 画像処理エンジン | NSImage / CoreGraphics（Swift純正） |
| フォルダ監視 | FSEvents（DispatchSource.makeFileSystemObjectSource or FileManager + DispatchQueue） |
| 設定保存 | UserDefaults |
| 最小対応 OS | macOS 13 Ventura 以降 |
| 配布 | Mac App Store |

---

## アーキテクチャ

```
┌─────────────────────────────────────────────┐
│  MenuBarApp (SwiftUI App)                   │
│  ├── MenuBarView (ドロップダウンメニュー)      │
│  │   ├── ON/OFF トグル                       │
│  │   ├── 現在の設定表示                       │
│  │   ├── Settings...                        │
│  │   ├── About...                           │
│  │   └── Quit                               │
│  ├── SettingsWindow (設定ウィンドウ)           │
│  │   ├── リサイズ設定                         │
│  │   ├── フォーマット・画質設定                │
│  │   ├── 保存方式設定                         │
│  │   ├── 監視フォルダ設定                     │
│  │   └── ログイン時自動起動                    │
│  ├── FolderWatcher (フォルダ監視)              │
│  └── ImageCompressor (画像圧縮処理)            │
└─────────────────────────────────────────────┘
```

---

## 機能仕様

### 1. メニューバー（Amphetamine スタイル — シンプル）

メニューバーアイコンをクリックすると表示されるドロップダウン。
Amphetamine のように必要最小限の項目のみ。余計なサブメニューは作らない。

```
┌─────────────────────────────┐
│  ✅ 自動圧縮: ON            │  ← クリックで ON/OFF トグル
│  ─────────────────────────  │
│  50% · JPEG 75%             │  ← 現在の設定（グレー、読み取り専用）
│  ─────────────────────────  │
│  設定...             ⌘ ,    │
│  ─────────────────────────  │
│  ShrinkShot について        │
│  ShrinkShot を終了   ⌘ Q   │
└─────────────────────────────┘
```

**メニューバーアイコン**: SF Symbols `arrow.down.right.and.arrow.up.left`（圧縮を示す）
- ON時: テンプレートアイコン（通常表示）
- OFF時: アイコンに斜線 or グレーアウト

**ショートカットキー**: `⌘,` で設定、`⌘Q` で終了（macOS 標準慣習に従う）

### 2. 設定ウィンドウ（Amphetamine の設定画面スタイル）

独立したウィンドウで表示。セクション分けされた macOS ネイティブな設定画面。
Amphetamine のように上部にアイコン付きタブバーは不要（設定項目が少ないため1画面で収める）。

#### 2.1 リサイズ設定

| 項目 | 仕様 |
|------|------|
| スケーリング % | スライダー: 10% 〜 100%（デフォルト 50%） |
| ラベル表示 | `元の寸法の XX% に画像をスケーリングします。` |

#### 2.2 フォーマット・画質設定

| 項目 | 仕様 |
|------|------|
| 出力フォーマット | ドロップダウン: `PNG（元のまま）` / `JPEG` |
| 画質スライダー | JPEG 選択時のみ表示。10% 〜 100%（デフォルト 75%） |

#### 2.3 監視フォルダ設定

| 項目 | 仕様 |
|------|------|
| 監視フォルダパス | テキスト表示 + 「変更...」ボタン（NSOpenPanel） |
| デフォルト | `~/Desktop`（macOS のスクショデフォルト保存先） |
| 対象ファイル | `.png` のみ（macOS スクショのデフォルト形式） |
| 保存方式 | 元ファイルを上書き（ON時のみ。OFFなら何もしない） |

#### 2.4 一般設定

| 項目 | 仕様 |
|------|------|
| ログイン時に自動起動 | トグル ON/OFF（SMAppService / LaunchAtLogin） |

---

## 画像圧縮処理フロー

```
[FolderWatcher: 新規 .png ファイル検出]
    │
    ├── ON/OFF チェック → OFF なら無視
    ├── ファイル拡張子チェック → .png 以外は無視
    ├── 自分が書き出したファイルかチェック → 自分なら無視（無限ループ防止）
    │
    ├── 0.5秒ディレイ（書き込み完了待ち）
    │
    ▼
[ImageCompressor]
    │
    ├── 1. NSImage で読み込み
    ├── 2. 元サイズ取得
    ├── 3. スケーリング % 適用して新サイズ計算
    ├── 4. CGContext でリサイズ描画
    ├── 5. フォーマットに応じて書き出し
    │      ├── PNG: NSBitmapImageRep → PNG data
    │      └── JPEG: NSBitmapImageRep → JPEG data（画質 % 適用）
    ├── 6. 元ファイルを上書き保存
    │
    ▼
[完了]
```

---

## フォルダ監視の実装方針

```swift
// FSEvents ベースの監視
// DispatchSource.makeFileSystemObjectSource は単一ファイル向きなので
// FSEventStream を使ってディレクトリ全体を監視する

// 注意点:
// - .png ファイルのみ対象
// - スクショ保存は「作成 → 書き込み完了」の2段階で発生する
// - 書き込み完了を待ってから圧縮処理を開始する必要がある
// - ファイルサイズが安定するまで短いディレイ（0.5秒）を入れる
// - 自分が書き出したファイルの変更イベントは無視する（フラグ管理で無限ループ防止）
```

---

## UserDefaults キー一覧

| キー | 型 | デフォルト値 |
|------|----|-------------|
| `isEnabled` | Bool | `true` |
| `scalePercentage` | Int | `50` |
| `outputFormat` | String | `"png"` |
| `jpegQuality` | Int | `75` |
| `watchFolderPath` | String | `"~/Desktop"` |
| `launchAtLogin` | Bool | `false` |

---

## MVP スコープ

### Phase 1（MVP）
- [x] メニューバー常駐 + ON/OFF トグル
- [x] 設定ウィンドウ（スケーリング%・フォーマット・画質・監視フォルダ・自動起動）
- [x] フォルダ監視（1フォルダ、.png のみ）
- [x] 自動圧縮 → 元ファイル上書き
- [x] PNG 維持 or JPEG 変換
- [x] ログイン時自動起動
- [x] 日本語 + 英語 ローカライズ

### Phase 2（将来）
- [ ] 圧縮前後のサイズ通知（macOS 通知センター）
- [ ] 圧縮履歴の表示（メニューに直近5件表示）
- [ ] ドラッグ＆ドロップで手動圧縮
- [ ] ショートカットキーで ON/OFF
- [ ] 複数フォルダ監視
- [ ] _shrink 付き保存 / 別フォルダ保存オプション
- [ ] HEIC / WebP / JPEG / TIFF 入力対応

---

## App Store 情報

| 項目 | 内容 |
|------|------|
| アプリ名 | ShrinkShot |
| サブタイトル | Auto-compress screenshots instantly |
| カテゴリ | ユーティリティ |
| 価格 | $2.99（買い切り） |
| キーワード | screenshot,compress,resize,shrink,image,optimize,menubar,retina |
| プライバシー | データ収集なし |
| Sandbox | 有効（ファイルアクセスはユーザー選択フォルダのみ） |

### App Store 説明文（案）

**EN:**
ShrinkShot lives in your menu bar and automatically compresses screenshots the moment they're saved. Perfect for pasting into Claude, ChatGPT, Slack, or Notion without hitting size limits.

- One-click ON/OFF toggle
- Customizable scale percentage and JPEG quality
- Watches your screenshot folder automatically
- Native macOS app — no dependencies, no subscriptions

**JA:**
ShrinkShot はメニューバーに常駐し、スクリーンショットを保存した瞬間に自動圧縮します。Claude・ChatGPT・Slack・Notion に画像を貼る時のサイズ制限問題を解決します。

- ワンクリックで ON/OFF 切り替え
- スケーリング率・JPEG 画質をカスタマイズ
- スクショ保存フォルダを自動監視
- macOS ネイティブ — 依存なし・サブスクなし

---

## プロジェクト構成

```
ShrinkShot/
├── ShrinkShot.xcodeproj
├── ShrinkShot/
│   ├── ShrinkShotApp.swift          # @main、MenuBarExtra
│   ├── MenuBarView.swift            # ドロップダウンメニュー
│   ├── SettingsView.swift           # 設定ウィンドウ
│   ├── AboutView.swift              # About ウィンドウ
│   ├── Models/
│   │   └── AppSettings.swift        # UserDefaults ラッパー（@AppStorage）
│   ├── Services/
│   │   ├── FolderWatcher.swift      # FSEvents フォルダ監視
│   │   └── ImageCompressor.swift    # NSImage/CoreGraphics 圧縮処理
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/
│   └── Info.plist
├── CLAUDE.md                         # Claude Code 用コンテキスト
└── README.md
```

---

## CLAUDE.md（Claude Code 用）

以下の内容を `CLAUDE.md` としてプロジェクトルートに配置:

```markdown
# ShrinkShot — Claude Code コンテキスト

## プロジェクト概要
macOS メニューバー常駐アプリ。スクショ保存先フォルダを監視し、新規 .png を自動圧縮する。
ON なら圧縮上書き、OFF なら何もしない。シンプル。

## 技術スタック
- Swift + SwiftUI
- 画像処理: NSImage / CoreGraphics（sips 不使用）
- フォルダ監視: FSEvents
- 設定: UserDefaults / @AppStorage
- 最小 OS: macOS 13 Ventura

## 重要な設計判断
- メニューバーUI は Amphetamine アプリのスタイルを参考にする（シンプル、フラット、サブメニューなし）
- 設定画面の圧縮UIは bulkresizephotos.com を参考にする（スライダー + ドロップダウン）
- 圧縮エンジンは sips ではなく NSImage/CoreGraphics を使う（画質スライダー対応のため）
- App Sandbox 有効（Mac App Store 配布のため）
- 対象ファイルは .png のみ（macOS スクショのデフォルト形式）
- 保存方式は元ファイル上書きのみ（シンプルに）
- 監視フォルダは1つのみ（MVP）
- 無限ループ防止: 自分が書き出したファイルはフラグ管理で無視
- スクショ書き込み完了を待つため 0.5 秒ディレイを入れる
- 日本語 + 英語のローカライズ対応

## コーディング規約
- SwiftUI の @AppStorage で UserDefaults を直接バインド
- MVVM は不採用（シンプルなアプリなので過剰）
- ファイル操作は FileManager 経由
- エラーは print + 通知（クラッシュさせない）

## ファイル構成
- ShrinkShotApp.swift: @main、MenuBarExtra 定義
- MenuBarView.swift: ドロップダウンメニュー
- SettingsView.swift: 設定ウィンドウ（リサイズ・フォーマット・監視フォルダ・自動起動）
- AppSettings.swift: UserDefaults キー定義
- FolderWatcher.swift: FSEvents でフォルダ監視
- ImageCompressor.swift: NSImage/CoreGraphics で圧縮

## 現在の Phase
MVP（Phase 1）を実装中。通知・履歴・D&D・複数保存方式は Phase 2。
```

---

## 参考 UI

### メニューバードロップダウン（Amphetamine 風）
- 最小限の項目（ON/OFFトグル、現在設定、設定...、について、終了）
- サブメニューなし、フラットな構成
- ショートカットキー付き（⌘, / ⌘Q）

### 設定画面（Amphetamine 設定 + BULK RESIZE PHOTOS 風）
- タブ分割なし（項目が少ないので1画面に収める）
- セクション分け（General / Resize / Output / Watch Folder）
- スライダー + 数値表示
- ドロップダウン選択
- ダークモード対応
