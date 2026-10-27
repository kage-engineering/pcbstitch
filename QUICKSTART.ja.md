# クイックスタート

[English version](QUICKSTART.md) ・ 詳しい説明は [README](README.md)(英語)を参照してください。

`pcbstitch` は、基板を少しずつ重ねて撮った複数の写真を、1 枚の大きく鮮明な画像につなぎ合わせるツールです。

## 1. インストール(最初の 1 回だけ)

ターミナルを開き、次の 1 行を貼り付けて Enter を押してください。
```
curl -fsSL https://raw.githubusercontent.com/kage-engineering/pcbstitch/main/setup.sh | bash
```
- **パスワード:** インストールが必要なものがあると、パスワードを聞かれます。入力中は何も表示されませんが、正常です。そのまま入力して Enter を押してください。
- **やること:** 必要なものをすべてインストールし、pcbstitch を `~/pcbstitch` に置いて、テスト実行まで行います。Arch/CachyOS、Ubuntu/Debian、Fedora、openSUSE で使えます。
- **「完了しました!」と表示されたら**、ターミナルを閉じて新しいターミナルを開き、`pcbstitch --help` を試してください。
- **後で更新するとき**は、同じ 1 行をもう一度実行してください。

<details>
<summary>手動でインストールする場合(1 ステップずつ行いたい人向け)</summary>

**Arch / CachyOS**
```
sudo pacman -S git hugin enblend-enfuse rawtherapee uv
```

**Ubuntu / Debian**
```
sudo apt install git hugin-tools enblend rawtherapee
curl -LsSf https://astral.sh/uv/install.sh | sh
```

次に pcbstitch をダウンロードし、`pcbstitch` コマンドをインストールします。
```
git clone https://github.com/kage-engineering/pcbstitch.git
cd pcbstitch
./install.sh
```
`install.sh` は `pcbstitch` を **どのフォルダからでも** 実行できるようにします(bash・zsh・fish の PATH に追加します)。必要なツールが足りない場合は警告を表示します。

**新しいターミナルを開いて**、どのフォルダからでも動くか確認します。
```
pcbstitch --help
```
初回の実行時は Python パッケージをダウンロードするため、少し時間がかかります。

更新するとき: `cd pcbstitch && git pull`(再インストールは不要です)。
削除するとき: `./install.sh --uninstall`。

</details>

## 2. 写真を撮る

- **一列に並べて撮る。** 基板の片面を上から下、または左から右へ一列に撮り、隣の写真と **約 3 分の 1** 重なるようにします。
- **カメラを固定する。** カメラの高さとピントは全ての写真で同じにします。
- **固定されていない部品には触らない。** 撮影の合間にケーブル・アンテナ基板・パッドなどを動かさないでください(テープで固定するのがおすすめです)。
- **ファイル名は順番どおりに付ける**(例: `front1`, `front2`, `front3`)。同じ位置の写真は、良い 1 枚だけ残してください。
- **片面は 1 回の撮影でまとめて撮る。** 撮影の合間(例えば別の日)に固定されていない部品が動くと、その部品が二重に写ったり途中で切れたりすることがあります。

## 3. つなぎ合わせる

写真のあるフォルダに移動し、写真を順番どおりに指定します。
```
cd ~/Pictures/myboard
pcbstitch front1.ARW front2.ARW front3.ARW
pcbstitch back1.ARW back2.ARW back3.ARW
```
Sony の `.ARW` などの RAW ファイルは、自動的に PNG に変換されて `png/` フォルダに保存されます。PNG・TIFF・JPEG を直接指定することもできます。

**その列の写真だけを指定してください。** フォルダにチップの接写など別の写真も入っている場合は、`pcbstitch *.ARW` は使わないでください。新しい範囲を何も含まない余分な写真を指定した場合は、自動的に除外してその旨を表示します(`skipping …`)。撮影時刻が離れた写真が混ざっている場合は警告を表示します。

結果は `stitched/` フォルダに保存されます。
```
myboard/
├── front1.ARW  front2.ARW  front3.ARW ...
├── png/                    ← 変換された写真
└── stitched/
    ├── front_stitched.png  ← 完成画像
    ├── front_stitched.pto  ← Hugin のプロジェクトファイル
    └── front_stitched.log  ← 問題が起きたときの詳細ログ
```

## 4. 結果を確認する

最後に次のような表示が出ます。
```
done: front_stitched.png 5942x8406
  control points 132, mean error 1.14px, max 2.99px
  ghost pixels 610 in 0 region(s)
```
- **mean error が 1 px 前後、max が 4 px 程度以下:** 良好です。
- **0 region(s):** 目立つつなぎ目の失敗はありません。
- **region がある場合**は `--qa-image` を付けて再実行し、`stitched/front_qa.jpg` を開いてください。問題のある場所が赤く表示されます。多くの場合、撮影の合間に何かが動いたことが原因です。固定されていない部品を動かさないようにして撮り直してください。

写真が重なっている部分を中心に、必ず自分の目でも画像を確認してください。

## 5. 便利なオプション

| オプション | 使う場面 |
|---|---|
| `--rotate 180` | 基板が上下逆さまになった場合(90 / 270 も可)。PNG が既にある場合は `--redevelop` も付ける |
| `--name board_front` | 出力ファイル名を指定する(`board_front_stitched.png`) |
| `--qa-image` | 問題のある場所を示す画像を保存する |
| `-o フォルダ` | 結果を別の場所に保存する |

すべてのオプションは `pcbstitch --help` で確認できます。

## 6. うまくいかないとき

| メッセージ | 対処 |
|---|---|
| `pcbstitch: command not found` | `./install.sh` の後に新しいターミナルを開いてください。それでも動かない場合は、`pcbstitch` フォルダで `./install.sh` をもう一度実行してください |
| `missing tools: …` | 手順 1 のツールをインストールしてください |
| `need at least two images` | 写真を 2 枚以上指定してください |
| `images could not all be connected` | 写真の重なりが足りないか、別の面の写真が混ざっています。順番と重なりを確認してください |
| `photos were taken at different times` | 別の撮影時の写真が混ざっています。結果がおかしい場合は、同じ撮影時の写真だけを使ってください |
| `skipping X: its whole area is covered` | 正常な動作です。X は新しい範囲を含まないため除外されました。指定した写真が正しいか確認してください |
| `has no focal length in EXIF` | 写真にカメラ情報がありません。`--focal 90`(使ったレンズの焦点距離)を付けてください |

それでも解決しない場合は、`stitched/` フォルダの `.log` ファイルをこのツールの管理者に送ってください。
