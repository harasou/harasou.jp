---
title: "markdown(GFM) を変換するコマンドを mruby-cli で作ってみた"
date: 2015-12-20T13:41:27+09:00
tags:
  - mruby
url:            2015/12/20/gfmarkdown-release
thumbnailImage: 2015/12/20/gfmarkdown-release/mruby_logo_red_icon.png
---

この記事は、[mruby advent calendar 2015](http://qiita.com/advent-calendar/2015/mruby) 20日目の記事です。みなさん難しい記事が多いですが、私にそういうのは無理なので軽めの内容になっています。

<!--more-->

はじめに
======================================================================

mruby でコマンドラインツールを作成できる [mruby-cli](https://github.com/hone/mruby-cli) を使って、markdown を html に変換する `gfmarkdown` というコマンドを作ってみました。

mruby-cli は、コマンドを作成するための雛形の作成とコンパイルなどを行ってくれるもので、一つのソースから、Linux や Mac、Windows などで動作するバイナリを生成してくれます。

markdown から html への変換は、[Github の API](https://developer.github.com/v3/markdown/) を利用しました。このため、インターネットへ接続できない環境では使用できません。


gfmarkdown のインストール
======================================================================

各アーキテクチャごとのバイナリを用意しているので、ダウンロード＆展開する。(現状、windows 版はないです)

https://github.com/harasou/gfmarkdown/releases


```
curl -fsSLO https://github.com/harasou/gfmarkdown/releases/download/v0.0.1/gfmarkdown-0.0.1-x86_64-apple-darwin14.zip
unzip gfmarkdown-*.zip
```
```sh
$ ./gfmarkdown

Usage: gfmarkdown [options] file
      --mode=markdown|gfm
                      The rendering mode. markdown or gfm. default markdwon.
      --context=repository
                      he repository context. Only taken into account when rendering as gfm
      --url=url       domain (or through https://yourdomain.com/api/v3/markdown for enterprise)
      --token=token   OAuth2 Token
      --version       print the version
      --help          show this message, -h for short message
```

使い方
======================================================================
テスト用の markdown ファイル `TEST.md`
```sh
$ cat TEST.md
## rendering
- harasou/mruby-gfmarkdown#1
- #1
```

1. 通常の変換

    ```html
    $ ./gfmarkdown TEST.md
    <h2>
    <a id="user-content-rendering" class="anchor" href="#rendering" aria-hidden="true"><span class="octicon octicon-link"></span></a>rendering</h2>
    
    <ul>
    <li>harasou/mruby-gfmarkdown#1</li>
    <li>#1</li>
    </ul>
    ```

1. `mode=gfm` を指定すると、Issue へのリンクが追加される

    ```html
    $ ./gfmarkdown --mode=gfm TEST.md
    <h2>rendering</h2>
    
    <ul>
    <li><a href="https://github.com/harasou/mruby-gfmarkdown/issues/1" class="issue-link js-issue-link" data-url="https://github.com/harasou/mruby-gfmarkdown/issues/1" data-id="123095833" data-error-text="Failed to load issue title" data-permission-text="Issue title is private">harasou/mruby-gfmarkdown#1</a></li>
    <li>#1</li>
    </ul>
    ```

1. `context` を追加すると `#1` などが context で指定したリポジトリのリンクになる

    ```html
    $ ./gfmarkdown --mode=gfm --context=harasou/mruby-gfmarkdown TEST.md
    <h2>rendering</h2>
    
    <ul>
    <li><a href="https://github.com/harasou/mruby-gfmarkdown/issues/1" class="issue-link js-issue-link" data-url="https://github.com/harasou/mruby-gfmarkdown/issues/1" data-id="123095833" data-error-text="Failed to load issue title" data-permission-text="Issue title is private">harasou/mruby-gfmarkdown#1</a></li>
    <li><a href="https://github.com/harasou/mruby-gfmarkdown/issues/1" class="issue-link js-issue-link" data-url="https://github.com/harasou/mruby-gfmarkdown/issues/1" data-id="123095833" data-error-text="Failed to load issue title" data-permission-text="Issue title is private">#1</a></li>
    </ul>
    ```


[bcat](http://rtomayko.github.io/bcat/) などを使うとブラウザで確認できるので便利です。
```
./gfmarkdown TEST.md | bcat
```

markdown の変換
======================================================================

Github の API を利用しているので、https での通信が必要ですが、これは matsumoto-r さんの [mruby-httprequest](https://github.com/matsumoto-r/mruby-httprequest) を利用しました。
これを使えば、API の通信がワンライナーでかけてしまいます。実際、`gfmarkdown` で利用している mgem はこんなシンプルなものです。

```ruby
class GFMarkdown

  def initialize(opt = {})
    @url = opt[:url] ? opt[:url] : "https://api.github.com/markdown"
    @token = opt[:token]
    @mode = opt[:mode]
    @context = opt[:context]
  end

  def render text
    headers = {
      'User-Agent' => "mruby-gfmarkdown",
    }
    headers['Authorization'] = "token #{@token}" if @token

    postdata = {
      :text => text,
    }
    postdata[:mode] = @mode if @mode
    postdata[:context] = @context if @context

    HttpRequest.new().post(@url,JSON.generate(postdata),headers).body
  end

end
```

コマンドの作成
======================================================================

バイナリの作成は、hone さんの [mruby-cli](https://github.com/hone/mruby-cli) を利用しています。簡単に mruby-cli を使ったバイナリの作り方を紹介します。


1. mruby-cli コマンドの取得

    mruby-cli のリポジトリ自体は `mruby-cli` コマンドを作成するものなので特に不要で release からダウンロードできるコマンドがあればよいです。
    ```
    curl -fsSL https://github.com/hone/mruby-cli/releases/download/v0.0.4/mruby-cli-0.0.4-x86_64-apple-darwin14.tgz | tar zx -
    ```

1. テンプレートの作成

    取得したバイナリを実行してテンプレートを作成します

    ```
    ./mruby-cli --setup gfmarkdown
    ```
    ```
    $ la gfmarkdown/{,mrblib*,tools/*}
    gfmarkdown/:
    total 48
    drwxr-xr-x  12 harasou  harasou   408 12 20 16:46 ./
    drwx------+ 14 harasou  harasou   476 12 20 16:46 ../
    -rw-r--r--   1 harasou  harasou     7 12 20 16:46 .gitignore
    -rw-r--r--   1 harasou  harasou    20 12 20 16:46 Dockerfile
    -rw-r--r--   1 harasou  harasou  1939 12 20 16:46 Rakefile
    drwxr-xr-x   3 harasou  harasou   102 12 20 16:46 bintest/
    -rw-r--r--   1 harasou  harasou  2163 12 20 16:46 build_config.rb
    -rw-r--r--   1 harasou  harasou   324 12 20 16:46 docker-compose.yml
    -rw-r--r--   1 harasou  harasou   299 12 20 16:46 mrbgem.rake
    drwxr-xr-x   4 harasou  harasou   136 12 20 16:46 mrblib/
    drwxr-xr-x   3 harasou  harasou   102 12 20 16:46 test/
    drwxr-xr-x   3 harasou  harasou   102 12 20 16:46 tools/
    
    gfmarkdown/mrblib:
    total 8
    drwxr-xr-x   4 harasou  harsou  136 12 20 16:46 ./
    drwxr-xr-x  12 harasou  harsou  408 12 20 16:46 ../
    drwxr-xr-x   3 harasou  harsou  102 12 20 16:46 gfmarkdown/
    -rw-r--r--   1 harasou  harsou  120 12 20 16:46 gfmarkdown.rb
    
    gfmarkdown/tools/gfmarkdown:
    total 8
    drwxr-xr-x  3 harasou  harasou  102 12 20 16:46 ./
    drwxr-xr-x  3 harasou  harasou  102 12 20 16:46 ../
    -rw-r--r--  1 harasou  harasou  700 12 20 16:46 gfmarkdown.c
    ```

    コマンド実装する mruby の処理は `gfmarkdown/mrblib/gfmarkdown.rb` に書きます。必要な mgem などは、普通に mruby をビルドするときと同様に `gfmarkdown/build_config.rb` です。

    `gfmarkdown/tools/gfmarkdown/gfmarkdown.c` ここに main() があり、gfmarkdown.rb の処理がバイトコードとして組み込まれてバイナリが作成される感じになります。

    refs: [gfmarkdown でのテンプレートからの変更箇所](https://github.com/harasou/gfmarkdown/commit/18afad0db8dc7146602dd94f3d122d59f989287c)

1. コンパイル

    mruby-cli はコンパイルで docker を利用しています(クロスビルドが必要なければ、docker がなくても大丈夫です)。Mac の場合だと Docker Toolbox を利用するかと思います。

    refs: http://harasou.github.io/2015/08/15/Docker-Toolbox/

    Docker Toolbox がインストールされているとこんな感じでコンパイルします。(default という仮想マシンを利用しています)

    ```sh
    cd gfmarkdown
    eval $(docker-machine env default)
    docker-compose run compile
    ```
    mruby 本体及び、必要な mgem がダウンロードされ、コンテナ上でコンパイルされます。コンパイルされたバイナリは下記ディレクトリにされます。
    ```sh
    $ ls -l mruby/build/*/bin/gfmarkdown
    -rwxr-xr-x  1 harasou  harasou   884064 12 20 17:10 mruby/build/host/bin/gfmarkdown*
    -rwxr-xr-x  1 harasou  harasou   421612 12 20 17:10 mruby/build/i386-apple-darwin14/bin/gfmarkdown*
    -rwxr-xr-x  1 harasou  harasou  1508291 12 20 17:10 mruby/build/i686-pc-linux-gnu/bin/gfmarkdown*
    -rwxr-xr-x  1 harasou  harasou   421056 12 20 17:10 mruby/build/x86_64-apple-darwin14/bin/gfmarkdown*
    -rwxr-xr-x  1 harasou  harasou   395992 12 20 17:10 mruby/build/x86_64-pc-linux-gnu/bin/gfmarkdown*
    ```
    なお、debug などでコンテナ環境を見たいときは、以下のような感じでコンテナにログインできます。
    ```sh
    $ docker-compose run shell
    root@bb22c9acb029:/home/mruby/code# uname -a
    Linux bb22c9acb029 4.0.9-boot2docker #1 SMP Thu Aug 13 03:05:44 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
    ```


さいごに
======================================================================

コマンドラインツールの作成とかだと、最近では golang の方が一般的だと思いますが、ライブラリとして組み込めるのは mruby の良さだと思います。

今回、mruby-gfmarkdown という mgem を作成してコマンドを作りましたが、次は、この mgem を組み込んだライブラリ `libmruby.a` を利用して、Mac の Quilck Look アプリ(.md をプレビューする)を作成したいと画策してます。
