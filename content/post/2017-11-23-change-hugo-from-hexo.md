---
title: "ブログを hexo から hugo に変更した"
date: 2017-11-23T13:40:00+09:00
tags:
  - hugo
url:            2017/11/23/change-hugo-from-hexo
thumbnailImage: 2017/11/23/change-hugo-from-hexo/hugo-logo-h.png
---

![](hugo-logo.png)

[hugo] は golang製の静的サイトジェネレータ。以前は hexo を利用していたが、hexo で利用していたテーマ tranquilpeak の [hugo版] が存在していたので、こちらに乗り換えた。

[hugo]: https://gohugo.io/
[hugo版]: https://github.com/kakawait/hugo-tranquilpeak-theme

<!--more-->

## セットアップ

[Getting Started] を見ながらなぞっていく。とりあえず手元の MAC で hugo が実行できる環境を構築する。

[Getting Started]: https://gohugo.io/getting-started/quick-start/

```
brew install hugo
```

新規にサイトを作って、テーマを設定。
```
cd ~/src/github.com/harasou/ # ブログを管理する適当なディレクトリに移動
hugo new site harasou.jp
cd $_
git init
git submodule add https://github.com/kakawait/hugo-tranquilpeak-theme.git themes/tranquilpeak
echo 'theme = "tranquilpeak"' >> config.toml
git add .
git commit -m "initial commit."
```

新規にページ作って表示してみる。http://127.0.0.1:1313/ へアクセス。

```
hugo new post/hugo-test.md
vim content/post/hugo-test.md
hugo server -D
```

テーマの設定を何もしてないので、まともに見れないが、なんとなく表示されている。

ハマったのが、今回使用したテーマ tranquilpeak では、post 配下にページを作らないと認識してくれなかったこと。あと動作確認時の`hugo server`は、デフォルト `--watch` が有効なので、`-D, --buildDrafts` だけあればよさそう。

## 移行作業

hexo も hugo も Front-matter 付きの markdown なので、移行自体にはそれほど手間はかからなかった。移行の方針としては permalink やファイル構成がなるべく現行と変わらないように。ざっくりこんな感じのことをやった。

1. 記事を`content/post/`配下に cp
1. 記事の Front-matter にある`date:`を RFC3339 に変換
1. 記事の Front-matter に`slug:`を追加 (ex.`slug: 2017/11/23/hugo-test`)
1. 記事の Front-matter にある`thumbnailImage:`のパスを slug 配下に変更
1. 画像を記事に合わせたディレクトリ`static/:slug/`配下に cp

それぞれの作業はワンライナーで適当に。あとは、サイト全体の設定とテーマの設定を`config.toml`で行う。

## Makefile

hexo からの移行で以下の2点が不満だったので、Makefile で代替している。

- public 配下をプレビューできない
- hugo new する時のパス名の指定や画像用ディレクトリの作成が面倒


```
.PHONY: build server public clean new

HUGO := hugo
PREFIX := $(shell date +post/%Y-%m-%d)
IMGDIR := $(shell date +static/%Y/%m/%d)

build: clean
	$(HUGO)

server:
	$(HUGO) server -D

public: clean
	$(HUGO) --baseURL http://127.0.0.1:8000/
	cd public; python -m http.server 8000 --bind 127.0.0.1

clean:
	@-rm -r public/
	@-find static -type d -empty | xargs rmdir

new:
	@: dummy

.DEFAULT:
	@case $(firstword $(MAKECMDGOALS)) in \
	new) \
		mkdir -p $(IMGDIR)/$@; \
		$(HUGO) new $(PREFIX)-$@.md --editor vim; \
		;; \
	esac
```

１つ目の publicディレクトリのプレビューには python 3系を利用。下記コマンドで、publicディレクトリをドキュメントルートしたサーバが立ち上がる。

```
make public
```

２つ目の`hugo new`の省力化については、

```
make new hugo-test
```
とすると、以下のような日付付きの記事ファイル`.md`と画像用のディレクトリができるようにした。
```
content/post/2017-11-23-hugo-test.md
static/2017/11/23/hugo-test/
```
記事の中身は `archetypes/post.md` で変更しているので、初期状態でこんな感じになる。
```
---
title: "hugo-test"
date: 2017-11-23T20:30:51+09:00
tags:
  -
url:            2017/11/23/hugo-test
thumbnailImage: 2017/11/23/hugo-test/
---
```
make 便利。
