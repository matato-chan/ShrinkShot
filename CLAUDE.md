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
