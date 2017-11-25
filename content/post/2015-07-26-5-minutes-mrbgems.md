---
title: "5分でつくる mrbgems"
date: 2015-07-26T21:32:19+09:00
tags:
  - mruby
slug: 2015/07/26/minutes-mrbgems
---

先日の関西Ruby会議の帰りの飛行機の中、着陸５分前ぐらいの出来事。

harasou: 「松本さん、mrbgems の作り方教えてくださいよ」
matusmotory:「じゃあ、まづ mrblib ってディレクトリ作って...」

おもむろに二人並んで PC を取り出し、mrbgems を作り始めた（着陸直前だったので、PC出して良かったのかよくわからないが...）
というわけで、その時のことを簡単にご紹介。

<!--more-->

そもそも mrbgems とは
----------------------------------------------------------------------

mrbgems は、CRuby の gem みたいなもので、mruby コアに色々な機能(ライブラリ)を追加する仕組み。ただ、CRuby のように動的にロードできるわけでなく、mruby コンパイル時に明示的に組み込んでおく必要がある。

この mrbgems は、mruby スクリプトだけで作成することもできるし、C言語だけ、あるいは、C言語 + mruby といった組み合わせたもので作成することもできる。

- mruby だけで実装
- C言語だけで実装
- C言語 + mruby で実装


飛行機では、一番簡単な mruby だけの実装をやった。


mrbgems はじめの一歩
----------------------------------------------------------------------
ここでは、設定した名前を返すだけの `yourname`メソッドを実装した `mruby-yourname` をつくった。 

1. mrbgems 用のディレクトリ作成

    ```
    mkdir -p work/mruby-yourname/mrblib/
    cd work
    ```

1. Yourname クラスの作成
    
    ```
    vim mruby-yourname/mrblib/yourname.rb
    ```
    ```rb mruby-yourname/mrblib/yourname.rb
    class Yourname
      def initialize name
        @name = name
      end
      def yourname
        puts @name
      end
    end
    ```

1. mrbgem.rake の作成

    ```
    vim mruby-yourname/mrbgem.rake
    ```
    ```rb mruby-yourname/mrbgem.rake
    MRuby::Gem::Specification.new('mruby-yourname') do |spec|
      spec.license= 'MIT'
      spec.authors= 'harasou'
    end
    ```

1. mruby を取得し、build_config.rb に mruby-yourname を追加

    ```
    git clone https://github.com/mruby/mruby.git
    vim mruby/build_config.rb
    ```
    ```diff
    --- mruby/build_config.rb.orig  2015-07-26 21:07:38.000000000 +0900
    +++ mruby/build_config.rb   2015-07-26 21:08:09.000000000 +0900
    @@ -18,6 +18,7 @@
       # conf.gem 'examples/mrbgems/c_and_ruby_extension_example'
       # conf.gem :github => 'masuidrive/mrbgems-example', :checksum_hash => '76518e8aecd131d047378448ac8055fa29d974a9'
       # conf.gem :git => 'git@github.com:masuidrive/mrbgems-example.git', :branch => 'master', :options => '-v'
    +  conf.gem '../mruby-yourname'
    
       # include the default GEMs
       conf.gembox 'default'
    ```

1. mruby のビルド

    ```
    cd mruby
    ./minirake
    ls -l bin/
    ```

事前に mruby は落としていたので、ここまで所要時間は 5分ぐらい。


動作確認
----------------------------------------------------------------------
mruby のシェル「mirb」で動作確認。

```
bin/mirb
```
```
mirb - Embeddable Interactive Ruby Shell

> y = Yourname.new("harasou")
 => #<Yourname:0x1425d70 @name="harasou">
>
> y.yourname
harasou
 => nil
```

できた。

実際は、実装をC言語で、インタフェースを mruby で書くことが多いと思うが、こんな簡単に自分の mrbgems を実装することができる。ぱちぱちぱち。
