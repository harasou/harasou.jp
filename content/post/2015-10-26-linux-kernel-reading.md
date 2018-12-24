---
title: "Linux kernel を読むための準備"
date: 2015-10-26T05:06:59+09:00
tags:
  - kernel
url:  2015/10/26/linux-kernel-reading
---

仕事で kernel のソースが見る機会が度々ありそうなので、MAC上でソースをいつでも追えるように準備しておく。
準備といっても大したものではなく、

- kernel ソースのダウンロード
- tag の作成
- vim の設定

ぐらい。tag については、GNU GLOBAL などもあるが、とりあえず ctags で。

<!--more-->

kernel source の取得
----------------------------------------------------------------------
github ではなく tar ball からの取得。複数のリリースを取得するにはこちらの方が簡単そうだったので。

```
mkdir -p ~/src/kernel
curl https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.2.4.tar.xz | tar zx -C ~/src/kernel/
```

tag の作成
----------------------------------------------------------------------
linux kernel の Makefile には、tag を作成するターゲットがあるので、make するだけで tag の作成ができる。

```
cd ~/src/kernel/linux-4.2.4
make tags
```

vim の設定
----------------------------------------------------------------------
ctags は、もともと vim の機能だったものが独立したらしいので、特に設定しなくても vim から使える。

使いそうなコマンド。

- ノーマルモード
    - `<C-[>` ：カーソル位置の単語にマッチする最初のタグにジャンプ
    - `g<C-[>`：カーソル位置に単語が複数マッチする場合、選択するようにユーザーにプロンプトを表示する。マッチが 1 つだけの場合、プロンプトを表示せずにジャンプする
    - `<C-t>` ：履歴をさかのぼる
- コマンドラインモード
    - `:tag {keyword}`：keyword に最初にマッチするタグにジャンプ
    - `:tselect`：タグマッチリストから選択してジャンプする
    - `:tag`：タグ履歴をたどる
    - `:pop`：タグ履歴をさかのぼる

少しだけカスタマイズ。やるのは、現在のところ２つだけ。

```
nnoremap  <C-]>    g<C-]>
nnoremap  v<C-]>   :vsp +:exec("tag\ ".expand("<cword>"))<CR>
set splitright     "新しいウィンドウを右にひらく
```

kernel source を眺め方
----------------------------------------------------------------------
kernel のソースは以下のようなディレクトリ構成になっていて、機能ごとに分かれているので、割と分かりやすい。ソースの大半はドライバのコードになっている(左の数値はduの結果)。

```sh
$ du -sh *
 20K    COPYING
 96K    CREDITS
 30M    Documentation/
4.0K    Kbuild
4.0K    Kconfig
316K    MAINTAINERS
 56K    Makefile
 20K    README
8.0K    REPORTING-BUGS
128M    arch/             #アーキテクチャ固有のカーネルコード
1.1M    block/
3.0M    crypto//
358M    drivers/
5.9M    firmware/
 36M    fs/
 32M    include/          #カーネルコードをビルドするのに必要なインクルードファイル
184K    init/             #カーネルの初期化(initialization)コード
244K    ipc/              #カーネルのプロセス間通信(inter-process communications)に関するコード
6.8M    kernel/           #カーネルの初期化コード
3.4M    lib/              
3.0M    mm/               #メモリ管理(memory management)コード
 26M    net/              #ネットワーク(network)関係のコード
384K    samples/
3.0M    scripts/
2.2M    security/
 29M    sound/
 43M    tags              #先ほど作成したタグ
 43M    tags-e
8.9M    tools/
 32K    usr/
300K    virt/
```
```sh
$ du -sh .
763M    .                  #全体(763M)の半分はドライバ周りのコード(358M)
```

例えば、「 kmalloc()って、slab からメモリ確保してるんだっけ？」って時は、

1. tag を生成したディレクトリに移動して、ソースを開く

    ```
cd ~/src/kernel/linux-4.2.4
vim .
```

1. kmalloc の定義にジャンプ

   ```
:tag kmalloc
```

1. `<C-]>` で辿っていく

    ```
kmalloc()
  -> __kmalloc()
    -> __do_kmalloc()
      -> slab_alloc()
```

って感じで「ああ、やっぱり slab 使ってんだ」というのが、すぐ確認できる。ソース見る習慣はやっぱ重要。
