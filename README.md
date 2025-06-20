# Talk to Text

高速で使いやすいMac用音声入力アプリです。Gemini APIを使用して音声認識結果を自動校正し、クリップボードへのコピーと現在のフォーカス位置への自動入力を行います。

## 主な機能

- **音声認識**: Apple Speech Recognitionを使用した高精度な音声認識
- **AI校正**: Gemini APIによる文章の自動校正・整形
- **グローバルショートカット**: カスタマイズ可能なキーボードショートカット
- **自動入力**: クリップボードへのコピー + アクティブアプリへの自動入力
- **メニューバーアプリ**: 軽量で常駐型のインターフェース

## システム要件

- macOS 13.0 以降
- マイクアクセス権限
- 音声認識権限
- アクセシビリティ権限（他のアプリへのテキスト入力用）
- インターネット接続（Gemini API使用）

## セットアップ

1. **Gemini APIキーの取得**
   - [Google AI Studio](https://aistudio.google.com/)でAPIキーを取得
   - アプリの設定画面でAPIキーを設定

2. **権限の設定**
   - 初回起動時に必要な権限を許可
   - アクセシビリティ権限：システム設定 > プライバシーとセキュリティ > アクセシビリティ

3. **ショートカットキーの設定**
   - デフォルト: Command + Shift + Space
   - 設定画面でカスタマイズ可能

## 使用方法

1. メニューバーのマイクアイコンをクリックしてアプリを確認
2. 設定したショートカットキーを押して録音開始
3. 音声入力（最大30秒まで自動録音）
4. 音声認識 → Gemini校正 → 自動入力の流れで処理

## 技術仕様

- **言語**: Swift 5.0
- **フレームワーク**: SwiftUI, Speech, AVFoundation, Carbon
- **音声認識**: Apple Speech Recognition (日本語)
- **AI処理**: Google Gemini API
- **アーキテクチャ**: ネイティブmacOSアプリ

## 開発・ビルド

```bash
# Xcodeでプロジェクトを開く
open talk_to_text.xcodeproj

# またはXcode CLIでビルド
xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Release
```

## ライセンス

MIT License