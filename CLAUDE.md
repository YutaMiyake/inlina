# inlina — agent 向けメモ

macOS のメニューバー常駐アプリ。テキスト選択 → ショートカットでフローティングパネルを出し、
カスタムプロンプトで AI に変換させて Replace する。SwiftPM 製(Xcode プロジェクトなし)。

## ビルドと適用(「apply して」と言われたらこれ)

```sh
./build-app.sh                      # release ビルド + inlina.app 生成 + ad-hoc 署名
pkill -x inlina
rm -rf /Applications/inlina.app && cp -R inlina.app /Applications/
open /Applications/inlina.app
```

- ad-hoc 署名なので上書きすると Accessibility 権限が外れることがある。効かない時は
  `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`
  で inlina のトグルを OFF → ON。
- デバッグビルドの確認だけなら `swift build`。
- Claude Code の sandbox 内では swift build が通らない(xcrun cache と Foundation の
  atomic write が `/var/folders` を要求し deny される。SwiftPM 自身の sandbox も
  二重適用できず失敗)。sandbox を無効にしてもらう必要がある(2026-08-04 実測)。

## 設定・カスタムプロンプトの保存場所

- UserDefaults ドメインは **`com.inlina.app`**(Info.plist の CFBundleIdentifier)。
- ⚠️ `inlina` という別ドメイン(裸バイナリ実行時代の残骸)が過去に存在し、
  それらしい中身が入っていて誤爆した(2026-08-04)。削除済みだが、`swift run` 等で
  bundle 外実行するとまた生まれる。**書き込む前に必ず両方確認すること**:
  `ls ~/Library/Preferences | grep -i inlina`
- プロンプトは key `inlina_customPrompts` に JSON(`[{id: UUID文字列, name, prompt}]`)を
  Data として保存。読み方:

  ```sh
  defaults export com.inlina.app - | plutil -extract inlina_customPrompts raw -o - - | base64 -d | python3 -m json.tool
  ```

- 外部から書き換える時は **必ずアプリを終了してから**(SettingsStore がメモリ上の値を
  didSet で書き戻すため、起動中に外から書いても上書きされうる)。手順:
  ①`pkill -x inlina` ② JSON を編集して `xxd -p` で hex 化し
  `defaults write com.inlina.app inlina_customPrompts -data <hex>` ③読み返して確認 ④`open /Applications/inlina.app`
- GUI からは Settings > Prompts でも編集できる(こちらが本来の経路)。

## コード構成

| ファイル | 役割 |
|---|---|
| `InlinaApp.swift` | エントリ。MenuBarExtra、AppDelegate(選択テキスト取得・Replace の paste 制御) |
| `FloatingPanel.swift` | NSPanel。サイズはここと FloatingPanelView の `.frame` の**2箇所**で合わせる |
| `FloatingPanelView.swift` | パネル UI。ソーステキスト欄(表示時に auto-focus) + 検索欄 + プロンプト 3 列グリッド。Enter = 先頭マッチ実行。検索欄は prompts 検索専用 |
| `SettingsView.swift` | Settings ウィンドウ(General / Shortcuts / Prompts / About) |
| `SettingsStore.swift` | UserDefaults 永続化。`CustomPrompt` 定義もここ |
| `AIService.swift` | OpenAI / Anthropic / Gemini 呼び出し |

- パネルからの Settings 起動は `@Environment(\.openSettings)` +
  `NSApp.setActivationPolicy(.regular)` → `activate` の順(MenuBarView と同じパターン)。
- 自由入力(検索欄の入力文を直接指示として実行)は廃止 → 復活 → 再廃止(いずれも 2026-08-04)。
  検索欄は prompts 検索のみ。復活させる時は `handleSubmit` に直接指示の分岐を戻す。
