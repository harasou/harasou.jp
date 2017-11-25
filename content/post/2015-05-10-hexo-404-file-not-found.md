---
title: "hexo で 404 File not found"
date: 2015-05-10T01:38:53+09:00
updated: 2015-06-28T12:10:00+09:00
tags:
  - hexo
slug: 2015/05/10/hexo-404-file-not-found
---

blog のトップページなどから`日本語タイトル`のリンクをたどると 404 になることがあった。

![](404.png)

<!--more-->

発生条件
----------------------------------------------------------------------
調べてわかった条件。

- MacOSX 上で記事を作成する。かつ
- `hexo new` で、濁点・半濁点を使ったタイトルをつける。かつ
- `hexo gen` した記事を MacOSX 以外にアップして blog を表示した場合。

例えば MacOSX 上で

```
hexo new "blog はじめました"
```

などすると「じ」が濁点付きの文字なので、これを gh-pages にアップしてみるとリンクが 404 になる。なお、

```
hexo server
open http://0.0.0.0:4000/
```

などして、MacOSX 上で確認すると問題ない。

原因
----------------------------------------------------------------------
自分は知らなかったが、結構有名な `NFD(Normalization Form D)` の問題だった。
これは、Unicode による文字の正規化の種類の話で、以下のようなものがある(他にも NFKD NFKC などがある)。

- NFD: 濁点・半濁点がついた `じ` などの文字を `し`+`”` の組み合わせで表す
- NFC: 濁点・半濁点がついた `じ` などの文字を `じ` 単体で表す

MacOSX で使用されているファイルシステム HFS+ は、日本語ファイル名の正規化に `NFD` を使用しているが、Linux や Windows は `NFC` が使われている。

MacOSX 上で `hexo gen` すると source/_post 配下のファイル名は NFD になっているため index.html 内にあるタイトルのリンクも `NFD` になる。

その後、`hexo deploy` などで Linux 系のサーバ(Github など)にデプロイすると、Linux 上のファイル名が `NFC` になるので、リンク(NFD)とファイル名(NFC)が違って 404 になってしまう。


対処
----------------------------------------------------------------------
deploy する際に、NFD -> NFC の変換をかけてやれば良い。が、うまい方法を見つけられなかった。

iconv や nkf は変換に対応しているが、記事のファイルは、タイトルが NFD、それ以外 NFC といったように混在しているため、実際に iconv で変換してみるとエラーになるものがあった。

また、以下のような変換を、hexo のプラグインとして作成できればベストだが、プラグラミングの能力がかなり低いので無理。

http://tsuyobi.heteml.jp/html/tools/nfd2nfc/

よって、かなりベタベタな sed で対応した。[このようなダサいスクリプト](https://github.com/harasou/harasou.github.io/blob/hexo/bin/nfd2nfc)を作成し、
`hexo deploy` 時に実行されるよう js を修正。

```diff
--- node_modules/hexo-deployer-git/lib/deployer.js.orig 2015-05-09 19:40:23.000000000 +0900
+++ node_modules/hexo-deployer-git/lib/deployer.js  2015-05-09 19:05:59.000000000 +0900
@@ -63,7 +63,12 @@
   }

   function push(repo){
-    return git('add', '-A').then(function(){
+    return spawn('../bin/nfd2nfc', '', {
+      cwd: deployDir,
+      verbose: verbose
+    }).then(function(){
+      return git('add', '-A');
+    }).then(function(){
       return git('commit', '-m', message).catch(function(){
         // Do nothing. It's OK if nothing to commit.
       });
```

これで、`hexo gen` するたびに濁点・半濁点のついた文字が NFC になるので、404 がなくなった。ダサいスクリプトについては、誰か助けてください。

2015/06/28 追記
----------------------------------------------------------------------
助けてくれました。こちらの記事でどうぞ。
[hexo の 404 File not found さようなら](/2016/05/28/hexo-goodby-404/)
