---
title: cat するたびに内容が変わるファイル？を作った 
date: 2018-12-31T23:42:04+09:00
tags:
  - linux
  - fuse
url:            2018/12/31/fuse-bindex
thumbnailImage: 2018/12/31/fuse-bindex/tokkuri.png
---

こんな感じ。
cat で連続して `now`ファイルの内容を表示している。ファイルを変更しているわけではないが、 
表示するたびに内容が変わる。

<!--more-->

```
# cat now
2018-12-27 00:21:20
# cat now
2018-12-27 00:21:21
# cat now
2018-12-27 00:21:23
```

Fuse-BindEx
-----------------------------------------------------------------------------------
どういう仕掛けかというと、今回作成した [bindex] ファイルシステムを経由して、
上記ファイルにアクセスしているため。この bindex というファイルシステムは、

**「実行ファイルが read されたら、そのファイルを execute した際の出力を内容として返す」**

という動作をする。上記`now`ファイルの本当の内容はこちら。

```
#!/bin/bash
date "+%F %T"
```

今回の場合、bindex 経由で cat (read) するたびに、date コマンドが実行(execute)され、
その結果が表示されていた。

ちなみに、bindex フィルシステムの作成には libfuse を利用している。libfuse については、
以前書いた記事「[libfuse で Hello World !][libfuse]」をどうぞ。


何の役に立つのか？
-----------------------------------------------------------------------------------
もちろん「いつでも現在時刻を表示してくれるファイル」が欲しかったわけじゃない。目的は、

**「アプリケーションが使用する設定ファイルなどを動的に生成すること」**

bindex を使用するとアプリケーションには全く意識させずに、設定ファイルなどを動的に生成できる。例えば、


### 1) nginx で使用する SSL証明書を DBで管理する

通常、SSL証明書などはファイルとして設置されているが、これを簡単にDB管理に変更できる。


設定ファイルには通常どおり証明書や鍵のパスを定義し、

```
server {
    listen 443 ssl;
    server_name harasou.jp;
    ssl_certificate /etc/nginx/ssl/harasou.jp.pem;
    ssl_certificate_key /etc/nginx/ssl/harasou.jp.key;
    ...
}
```

`/etc/nginx/ssl/`配下へのアクセスが bindex 経由になるよう、bindex コマンドでマウント。

```
bindex /opt/bindex/ssl /etc/nginx/ssl/
```

マウント元とした`/opt/bindex/ssl`配下に、SSL証明書などを取得するスクリプトを設置し、
実行権限を付与。

```
# cat -n /opt/bindex/ssl/harasou.jp.key
     1	#!/bin/bash
     2
     3	mysql -u root -sN <<__SQL__
     4	    SELECT
     5	        key
     6	    FROM
     7	        ssl_cert
     8	    WHERE
     9	        common_name = "harasou.jp"
    10	__SQL__
#
# chmod 700 /opt/bindex/ssl/harasou.jp.key
```

これで、`/etc/nginx/ssl/harasou.jp.key` が読みこまれた際、mysql から取得した情報が
渡されるようになる。


### 2) その他

- `httpd.conf`： apache の conf（VirtualHost など) を DB から参照して生成
- `/etc/hosts`： DNS 使わずに動的なホストの定義


レガシーな環境では、いろいろと使い道があると思う。


これから
-----------------------------------------------------------------------------------
まだ、とりあえず動くレベルなので、ちゃんとテストとか拡充して、会社のサービスに導入する予定。
1年近く放置していたプロダクトなので、来年はちゃんとやる。


<!--links-->
[libfuse]: https://harasou.jp/2017/12/04/fuse/
[bindex]: https://github.com/harasou/fuse-bindex
