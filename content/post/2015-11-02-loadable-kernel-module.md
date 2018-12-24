---
title: "カーネルモジュールで Hello World !"
date: 2015-11-03T01:14:38+09:00
tags:
  - kernel
url:  2015/11/03/loadable-kernel-module
---

Linux のカーネルモジュールで Hello World してみる。insmod、rmmod した時に dmesg にログを吐くだけの単純なもの。試した環境は、CentOS7 (3.10.0-123.4.4.el7.x86_64)。

<!--more-->

カーネルモジュールの作成
----------------------------------------------------------------------

1. 適当なディレクトリを作成

    ```sh
    mkdir -p ~/lkm/helloworld
    cd $_
    ```

1. ソースファイル

    ```c
    #include <linux/module.h>
    #include <linux/init.h>
    
    static int __init helloworld_init(void)
    {
        pr_info("Hello World!\n");
        return 0;
    }
    
    static void __exit helloworld_exit(void)
    {
        pr_info("Goodby World.\n");
    }
    
    module_init(helloworld_init);
    module_exit(helloworld_exit);
    MODULE_AUTHOR("harasou");
    MODULE_DESCRIPTION("Hello World Module");
    MODULE_LICENSE("MIT");
    ```
    ロードされた時と、アンロードされた時に、メッセージを出力するだけの単純なモジュール。
  
    - `module_init`： insmod したタイミングで呼ばれる関数を登録する
    - `module_exit`： rmmod したタイミグで呼ばれる関数を登録する
    - `MODULE_XXXX`： modinfo した時に表示される値を設定する

1. Makefile

    カーネルモジュールをコンパイルするための Makefile 。
    ```makefile
    KERNEL_DIR = /lib/modules/$(shell uname -r)/build
    BUILD_DIR := $(shell pwd)
    VERBOSE   := 0
    
    obj-m := helloworld.o
    
    all:
        make -C $(KERNEL_DIR) SUBDIRS=$(BUILD_DIR) KBUILD_VERBOSE=$(VERBOSE) modules
    
    clean:
        rm -rf  *.o *.ko *.mod.c *.symvers *.order .tmp_versions .helloworld.*
    ```

1. カーネルモジュールの作成

    make するだけで hellowrold.ko が作成される。
    ```sh
    $ ll
    合計 8
    -rw-rw-r--. 1 vagrant vagrant 300 10月 31 17:09 Makefile
    -rw-rw-r--. 1 vagrant vagrant 367 10月 31 16:42 helloworld.c
    $
    $ make
    make -C /lib/modules/3.10.0-123.4.4.el7.x86_64/build SUBDIRS=/home/vagrant/lkm/helloworld KBUILD_VERBOSE=0 modules
    make[1]: ディレクトリ `/usr/src/kernels/3.10.0-123.4.4.el7.x86_64' に入ります
      CC [M]  /home/vagrant/lkm/helloworld/helloworld.o
      Building modules, stage 2.
      MODPOST 1 modules
      CC      /home/vagrant/lkm/helloworld/helloworld.mod.o
      LD [M]  /home/vagrant/lkm/helloworld/helloworld.ko
    make[1]: ディレクトリ `/usr/src/kernels/3.10.0-123.4.4.el7.x86_64' から出ます
    $
    $ ll
    合計 204
    -rw-rw-r--. 1 vagrant vagrant   300 10月 31 17:09 Makefile
    -rw-rw-r--. 1 vagrant vagrant     0 10月 31 17:36 Module.symvers
    -rw-rw-r--. 1 vagrant vagrant   367 10月 31 16:42 helloworld.c
    -rw-rw-r--. 1 vagrant vagrant 91485 10月 31 17:36 helloworld.ko
    -rw-rw-r--. 1 vagrant vagrant   703 10月 31 17:36 helloworld.mod.c
    -rw-rw-r--. 1 vagrant vagrant 51112 10月 31 17:36 helloworld.mod.o
    -rw-rw-r--. 1 vagrant vagrant 41896 10月 31 17:36 helloworld.o
    -rw-rw-r--. 1 vagrant vagrant    50 10月 31 17:36 modules.order
    ```


動作確認
----------------------------------------------------------------------

insmod 時にログが表示される。
```sh
$ sudo /sbin/insmod helloworld.ko
$ lsmod | grep hellow
helloworld             12430  0
$
$ dmesg |tail -1
[84783.294666] Hello World!
```

rmmod 時にも表示される。
```sh
$ sudo /sbin/rmmod helloworld
$ dmesg |tail -1
[84802.982990] Goodby World.
```

modinfo で先ほど MODULE_XXXX で設定した内容が確認できる。
```sh
$ modinfo helloworld.ko
filename:       /home/vagrant/lkm/helloworld/helloworld.ko
license:        MIT
description:    Hello World Module
author:         harasou
srcversion:     9F090E897E652AF5A8BC5ED
depends:
vermagic:       3.10.0-123.4.4.el7.x86_64 SMP mod_unload modversions
```


感想
----------------------------------------------------------------------
iptables まわりを調べてる最中に、横道に逸れてカーネルモジュールの作り方を試した。時間があれば、モジュールパラメータ（/sys/module/modxxxx/parameters/xxxx）や proc ファイルシステムを利用したユーザプロセスとのやりとりなども調べてみたい。
