---
title: "GAE/Go で静的サイトを公開する"
date: 2018-01-28T02:21:58+09:00
tags:
  - GCP
  - Hugo
url:            2018/01/28/gaego-static-hosting
thumbnailImage: 2018/01/28/gaego-static-hosting/gaessl.png
---

Google Compute Engine 上の Nginx で運用していたブログを、GAE/Go (Go on Google App
Engine) に移行した。

<!--more-->

GAE/Go とは
-----------------------------------------------------------------------------------

GAE/Go は、Google が提供する Go言語用の PaaS 。[マネージドSSL][]の提供開始により、
カスタムドメインもつけるだけで SSL化されるようになった。

PaaS はアプリを動かすものだが、静的サイトを公開したければ、静的ファイルをを配信する
アプリを書けばよい。と言っても必要なファイルは2つだけ。

```
public/
main.go
app.yaml
```

GAE で公開(deploy)するための準備
-----------------------------------------------------------------------------------

GCPの開始や、gcloud の初期設定(デフォルトプロジェクトの登録など)が済んでいる状態で、
下記コマンドを実行し、GAE を東京リージョンで使える状態にする。

```
gcloud app create --region=asia-northeast1
```

次に、２つのファイルを public ディレクトリと同じ階層に作成。

main.go
```
package main

import "net/http"

func init() {
    http.Handle("/", http.FileServer(http.Dir("public")))
}
```
- public ディレクトリ配下を公開するアプリ

app.yaml
```
runtime: go
api_version: go1

skip_files:
- ^(?!main\.go|public)

handlers:
- url: /.*
  secure: always
  script: _go_app
```
- GAE の設定ファイル
- `skip_files:` で main.go と publicディレクトリのみ deploy するように指定
- `secure: always` で http を https にリダイレクト


GAE で公開
-----------------------------------------------------------------------------------

app.yaml があるディレクトリで、gcloud コマンドを実行すれば public 配下が公開される。

```
gcloud app deploy
```


このサイトの場合
-----------------------------------------------------------------------------------
このブログは Hugo を使っていて 、[以前書いた][]ように、Hugo の操作は全て [Makefile][]
を利用している。そのため、下記コマンドを打てば、public 配下が更新され、deploy が
実行される。make 便利。

```
make deploy
```

<!--links-->
[マネージドSSL]: https://cloudplatform-jp.googleblog.com/2017/10/introducing-managed-SSL-for-Google-App-Engine.html
[以前書いた]: https://harasou.jp/2017/11/23/change-hugo-from-hexo/#makefile
[Makefile]: https://github.com/harasou/harasou.jp/blob/master/Makefile
