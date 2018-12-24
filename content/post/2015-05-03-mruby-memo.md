---
title: "mruby についてのメモ"
date: 2015-05-03T04:16:53+09:00
tags:
  - mruby
url:  2015/05/03/mruby-memo
---

mruby の動作
----------------------------------------------------------------------

mruby の実行基盤である`RiteVM`は、Rubyスクリプトを逐次解釈して実行するのではなくコンパイル結果の`バイナリコード（Rite中間表現）`を直接実行する。

Rite中間表現をバイナリ出力したものが`mrbファイル(Riteバイナリファイル)`。


mrbgem とは
----------------------------------------------------------------------

mruby にライブラリを追加するための仕組み。mruby は require などで動的にライブラリを読み込めないので、mruby ビルド時に組み込む必要がある。
追加する際は、`build_config.rb` に追記してビルドする。

なお、mrbgem の実装には、以下３パターンがある。
- C拡張
- Ruby拡張
- C & Ruby 拡張

作り方については、この辺りが参考になりそう。
- [mrubyの拡張モジュールであるmrbgemのテンプレートを自動で生成するmrbgem作った](http://blog.matsumoto-r.jp/?p=3923)
- [mrbgemsの作り方メモ(勉強中)](http://qiita.com/hiroeorz@github/items/d6fa2978d9f53a41c777)


ireq とは
----------------------------------------------------------------------

まだ全然わかってないが、この辺り。

- https://github.com/mruby/mruby/issues/944#issuecomment-14556703


ライブラリ構成
----------------------------------------------------------------------

以下の４つが定義されているが、現在提供されているのはミニマルのみ？

- ミニマル: 実行に必要な最低限の機能
- スタンダード: JIS X 3017 規格相当
- フル: MRI(CRuby) のフル機能相当
- ドメイン別: 製品ドメイン別の拡張ライブラリ


参考リンク
----------------------------------------------------------------------

- [オフィシャルページ](http://forum.mruby.org/index.html)
- [ソース Github](https://github.com/mruby/mruby)
- [軽量 Ruby のご紹介と 軽量 Ruby フォーラムのご案内](http://forum.mruby.org/doc/Aboiut_mruby_forumJP.pdf)
- [IIJ 軽量Rubyへの取り組み](http://www.iij.ad.jp/company/development/tech/activities/mruby/)
- [mruby Advent Calendar 2013](http://qiita.com/advent-calendar/2013/mruby)
    - [mruby のビルド方法](http://qiita.com/masuidrive/items/e516c23b4feab73d139f)
    - [mrubyのバイトコードフォーマット解説](http://resemblances.click3.org/?p=1594)
