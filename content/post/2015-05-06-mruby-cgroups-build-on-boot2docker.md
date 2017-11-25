---
title: "mruby-cgroup を boot2docker で build する"
date: 2015-05-06T02:47:32+09:00
tags:
  - mruby
  - cgroup
slug: 2015/05/06/mruby-cgroups-build-on-boot2docker
---

mruby-cgroup とは
----------------------------------------------------------------------
mruby-cgroup は、@matsumotory が開発している mruby から cgroup を利用するためのライブラリ。

https://github.com/matsumoto-r/mruby-cgroup


cgroup は linux カーネルの機能で、タスク（プロセス）のリソース（CPU, メモリ, IO, etc）を制御するための仕組み。 これを利用すると「特定のプロセスが CPU100% 使うような処理を行っても 50% しか利用させない」といった制御ができるようになる。

<!--more-->

コンパイル環境について
---------------------------------------------------------------------
cgroup は Linux カーネルの機能であるため、MacOSX では利用できない。このため、MacOSX 上でコンパイルするには、クロスコンパイルの環境が必要。

ちょうど、@matsumotory が以下のようなエントリーを書かれていたが、mruby-cgroup の build には、cgroup のヘッダファイルなどが必要で手軽にできる感じではなかったので、とりあえず、VM 上でやることにする（今後試してみたい）。

> MacOSX上でLinuxとWindowsとOSXで動くmrubyバイナリを簡単にクロスコンパイルできるmrbgem作った
http://hb.matsumoto-r.jp/entry/2015/05/02/232220


boot2docker で build
----------------------------------------------------------------------
最近の boot2docker は、vboxfs に対応しているのですごく便利。

1. mruby の取得

    ```
    $ git clone https://github.com/mruby/mruby.git
    $ cd mruby
    ```

1. build_config.rb に mruby-cgroup を追加

    ```diff
    --- build_config.rb.orig    2015-05-06 03:03:22.000000000 +0900
    +++ build_config.rb 2015-05-06 03:04:28.000000000 +0900
    @@ -18,6 +18,7 @@
       # conf.gem 'examples/mrbgems/c_and_ruby_extension_example'
       # conf.gem :github => 'masuidrive/mrbgems-example', :checksum_hash => '76518e8aecd131d047378448ac8055fa29d974a9'
       # conf.gem :git => 'git@github.com:masuidrive/mrbgems-example.git', :branch => 'master', :options => '-v'
    +  conf.gem :git => 'https://github.com/matsumoto-r/mruby-cgroup.git'
    
       # include the default GEMs
       conf.gembox 'default'
    ```

1. build 用 image の作成

    ```
    $ docker pull centos:6
    $ cat <<EOD | docker build -t centos:mruby-cgroup -
    FROM centos:6
    RUN yum install -y git gcc bison ruby libcgroup-devel
    EOD
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED              VIRTUAL SIZE
    centos              mruby-cgroup        c80449f25327        About a minute ago   468.6 MB
    centos              6                   b9aeeaeb5e17        13 days ago          202.6 MB
    ```

1. mruby-cgroup の build

    ```
    $ docker run --rm -v $(pwd):/mruby centos:mruby-cgroup sh -c 'cd /mruby && ./minirake'
    ```

1. mruby に cgroup が組み込まれていることを確認

    ```
    $ ls -l bin
    total 34768
    -rwxr-xr-x  1 harasou  staff  3876694  5  6 03:41 mirb*
    -rwxr-xr-x  1 harasou  staff  2002059  5  6 03:41 mrbc*
    -rwxr-xr-x  1 harasou  staff  4122914  5  6 03:41 mrdb*
    -rwxr-xr-x  1 harasou  staff  3863412  5  6 03:41 mruby*
    -rwxr-xr-x  1 harasou  staff  3927759  5  6 03:41 mruby-strip*
    $
    $ docker run --rm -v $(pwd):/mruby centos:mruby-cgroup ldd /mruby/bin/mruby
        linux-vdso.so.1 =>  (0x00007ffd59dc3000)
        libm.so.6 => /lib64/libm.so.6 (0x00007fd65a047000)
        libcgroup.so.1 => /lib64/libcgroup.so.1 (0x00007fd659bd5000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fd659840000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fd659623000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fd65a2d0000)
    ```
