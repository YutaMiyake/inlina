# inlina

![inlina](inlina.png)

macOS メニューバーアプリ。テキストを選択してショートカットキーを押すだけで、AI によるテキスト編集をその場で実行できます。

## 特徴

- **どのアプリからでも使える** — テキストを選択 → ショートカットキー → AI が編集
- **複数の AI プロバイダー対応** — OpenAI / Anthropic / Google Gemini
- **豊富なアクション** — 文法修正、文章改善、要約、翻訳（日英）、簡略化、カスタムプロンプト
- **フローティングパネル UI** — カーソル付近に表示、作業を中断しない設計
- **カスタムプロンプト** — 自分だけの AI アクションを作成可能

## 必要環境

- macOS 14.0 (Sonoma) 以降
- Swift 5.9+
- Xcode Command Line Tools

## インストール

```bash
# ビルド
./build-app.sh

# Applications にコピー
cp -R inlina.app /Applications/
```

初回起動時に **アクセシビリティ権限** の付与が必要です（システム設定 → プライバシーとセキュリティ → アクセシビリティ）。

## 使い方

1. メニューバーから inlina を起動
2. 設定で **AI プロバイダー** と **API キー** を設定
3. **キーボードショートカット** を設定
4. 任意のアプリでテキストを選択 → ショートカットキーを押す
5. フローティングパネルからアクションを選択
6. 結果を「Replace」で置換、または「Copy」でコピー

## 対応 AI プロバイダー

| プロバイダー | デフォルトモデル | カスタム URL |
|-------------|----------------|-------------|
| OpenAI | gpt-4o | 対応 |
| Anthropic | claude-sonnet-4-20250514 | 対応 |
| Google Gemini | gemini-pro | 対応 |

カスタムベース URL を設定することで、Azure OpenAI やローカル LLM など任意のエンドポイントを利用できます。

## プロジェクト構成

```
inlina/
├── InlinaApp.swift          # アプリエントリポイント、アクセシビリティ API
├── AIService.swift          # AI API 通信
├── FloatingPanel.swift      # ウィンドウ管理
├── FloatingPanelView.swift  # フローティングパネル UI
├── SettingsView.swift       # 設定画面
├── SettingsStore.swift      # 設定管理
├── AIAction.swift           # AI アクション定義
└── ...
```

## ライセンス

MIT
