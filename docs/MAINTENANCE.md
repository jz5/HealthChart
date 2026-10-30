# HealthChart メンテナンスガイド

リリース・更新時に手動で行う必要がある作業のまとめ。

## 必要環境

- macOS + 最新の Xcode(現在 Xcode 26.x / iOS 26 SDK)
- Apple Developer Program のメンバーシップ(年会費あり・自動更新を推奨)
- 最低対応 OS: **iOS 17.0**(2025年の更新で 16.0 から引き上げ)

## 1. 証明書とプロビジョニングプロファイル(年1回程度)

Release ビルドは **手動署名**(`CODE_SIGN_STYLE = Manual`)で、次の設定を使っている:

| 設定 | 値 |
|---|---|
| 署名証明書 | iPhone Distribution(Team: `4XKKKM86RN`) |
| プロファイル | `Health care chart Provisioning Profile` |
| Bundle ID | `jp.pronama.healthcarechart` |

Debug ビルドは自動署名(Team: `2JDG8GM7G3`)。

### 期限切れ時の更新手順

1. [Apple Developer - Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list) を開く
2. **証明書(Distribution)が期限切れの場合**(有効期限は発行から約3年):
   1. Xcode → Settings → Accounts → Manage Certificates… → `+` → **Apple Distribution** で新規作成(または Web で CSR をアップロードして作成し、ダウンロードした `.cer` をダブルクリックでキーチェーンに取り込む)
   2. 証明書を作り直したら、それを使う下記プロファイルも作り直しが必要
3. **プロビジョニングプロファイルが期限切れの場合**(有効期限は1年):
   1. Profiles → `Health care chart Provisioning Profile` → **Edit**
   2. 新しい Distribution 証明書を選び直して **Generate** → ダウンロード
   3. `.mobileprovision` をダブルクリック、または Xcode の Signing 画面で選択し直す
   4. プロファイル名を変えた場合は `project.pbxproj` の `PROVISIONING_PROFILE_SPECIFIER` も合わせて変更する
4. 秘密鍵を失くすと証明書を再利用できないため、キーチェーンから書き出した `.p12` を安全な場所にバックアップしておく

> メンバーシップ自体が失効すると配信済みアプリが App Store から取り下げられるので、年会費の更新に注意。

## 2. HealthKit の権限文言

Info.plist 相当の設定はビルド設定の `INFOPLIST_KEY_NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` にある。読み取る項目を増やしてもコード変更だけで動くが、審査で文言の妥当性を見られることがある。

## 3. バージョン更新とリリース

1. `project.pbxproj` の `MARKETING_VERSION`(例 3.0 → 3.1)と `CURRENT_PROJECT_VERSION`(ビルド番号、単調増加)を上げる(Xcode の Target → General からでも可)
2. 実機向けに動作確認
3. Xcode: **Product → Archive**(scheme は HealthChart、Any iOS Device)
4. Organizer → **Distribute App → App Store Connect → Upload**
5. [App Store Connect](https://appstoreconnect.apple.com/) で新バージョンを作成し、「このバージョンの新機能」(日本語)を記入してビルドを選択 → 審査へ提出
6. HealthKit 利用アプリのため、審査でヘルスデータの利用目的を聞かれたら「読み取り専用でグラフ表示のみ、外部送信なし」と回答する

## 4. 依存パッケージ

- [swiftui-sliders](https://github.com/spacenation/swiftui-sliders)(SPM、`2.x`)
  - 参照 URL が `git@github.com:...`(SSH)なので、新しいマシンでは GitHub の SSH キー設定が必要。HTTPS に変えたい場合は Xcode の Package Dependencies で一度削除して `https://github.com/spacenation/swiftui-sliders.git` を追加し直す
  - 更新: Xcode → File → Packages → Update to Latest Package Versions

## 5. 新しい iOS / 新しいヘルスケア項目への対応

毎年の iOS メジャーアップデート時:

1. 最新 Xcode でビルドして deprecation 警告を確認
2. 新しい `HKQuantityTypeIdentifier` が追加されていないか [HealthKit のリリースノート](https://developer.apple.com/documentation/healthkit)を確認
3. 追加されていたら `Health.swift` の `buildItems()` に1行追加する:
   ```swift
   if #available(iOS 27.0, *) {
       items += [ make(.新タイプ, "表示名", .カテゴリ, 単位, "単位表示", "%.1f") ]
   }
   ```
   チャート種別(棒/折れ線)は集計スタイルから自動判定される。単位の互換性はユニットテストが検証する
4. 対応する最低 OS を上げる場合は `IPHONEOS_DEPLOYMENT_TARGET` を変更

## 6. 自動テストと動作確認

```bash
# ユニットテスト(シミュレーター)
xcodebuild test -project HealthChart.xcodeproj -scheme HealthChart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

テスト内容(`HealthChartTests/`):
- 月次キャッシュの保存・読み出し・クリア・単位不一致時の無効化
- クエリ範囲計算(キャッシュ済み月のスキップ、今月の再取得)
- 項目カタログの検証(タイプ重複なし、単位の互換性、累積型=棒グラフ)

シミュレーターにはヘルスケアデータがないため、グラフの実データ確認は実機か、シミュレーターの「ヘルスケア」アプリに手動でサンプル値を入れて行う。

## 7. キャッシュの仕様(トラブルシューティング用)

- 保存先: アプリの `Application Support/HealthChart/statsCache.json`
- 確定した過去の月の集計値のみ保存(今月は毎回再集計)
- ヘルスケア側で過去データを編集した場合は反映されないので、**設定 → キャッシュをクリア**を案内する
- アプリ削除で消える。バックアップには含まれる
