---
title: "カーネルモジュールの modinfo について"
date: 2015-11-04T00:00:36+09:00
tags:
  - kernel
url:            2015/11/04/kernel-module-modinfo
thumbnailImage: 2015/11/04/kernel-module-modinfo/elf.png
---

[前回カーネルモジュールを作った][1]際に、`MODULE_XXXX` というマクロでモジュール内に情報を埋め込んだが、これがどういう風に埋め込まれているのか調べてみた。環境は今回も CentOS7 (3.10.0-123.4.4.el7.x86_64)。

[1]:http://harasou.github.io/2015/11/03/loadable-kernel-module/

<!--more-->

前回作成した helloworld モジュールでも良いが、せっかくなので OS標準でインストールされているカーネルモジュール「iptalble_filter」について確認。

ELF(Executable and Linking Format)
----------------------------------------------------------------------

カーネルモジュールは ELFファイルになっている。

```sh
$ file iptable_filter.ko
iptable_filter.ko: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), BuildID[sha1]=0xbabd6cf7c7d83d359fa6aa7a5ad335bda58b0077, not stripped
```

ELFというのは、バイナリフォーマットの一つ（以前の Linux では a.out 形式も使用されていたらしいが、今はほとんどない）。

Linux では、カーネルモジュールだけではなく、実行ファイル、共有ライブラリなども ELF になっており、ELFファイルを扱うための専用のコマンド `elfread` `elfedit` も提供されている。

ELFファイルは、

- ELFヘッダ
- プログラムヘッダ
- セクションヘッダ

などのヘッダをもっているが、ELFファイル（オブジェクトファイル）の種類によって、必須のヘッダが異なる。プログラムヘッダは、実行ファイルが必要とするヘッダなので、カーネルモジュールではオプション扱いになる。

![](elf.png)

ref: https://ja.wikipedia.org/wiki/Executable_and_Linkable_Format

modinfo
----------------------------------------------------------------------

今回調べたかった modinfo の情報は、セクション`.modinfo` に格納されている。

iptable_filter.ko のヘッダ情報。プログラムヘッダはない。セクションヘッダに `.modinfo` の文字列が見える。

```sh
$ readelf -e iptable_filter.ko
ELF ヘッダ:
  マジック:  7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  クラス:                            ELF64
  データ:                            2 の補数、リトルエンディアン
  バージョン:                        1 (current)
  OS/ABI:                            UNIX - System V
  ABI バージョン:                    0
  型:                                REL (再配置可能ファイル)
  マシン:                            Advanced Micro Devices X86-64
  バージョン:                        0x1
  エントリポイントアドレス:          0x0
  プログラムの開始ヘッダ:            0 (バイト)
  セクションヘッダ始点:              5384 (バイト)
  フラグ:                            0x0
  このヘッダのサイズ:                64 (バイト)
  プログラムヘッダサイズ:            0 (バイト)
  プログラムヘッダ数:                0
  セクションヘッダ:                  64 (バイト)
  セクションヘッダサイズ:            26
  セクションヘッダ文字列表索引:      25

セクションヘッダ:
  [番] 名前              タイプ           アドレス          オフセット
       サイズ            EntSize          フラグ Link  情報  整列
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .note.gnu.build-i NOTE             0000000000000000  00000040
       0000000000000024  0000000000000000   A       0     0     4
  [ 2] .text             PROGBITS         0000000000000000  00000070
       0000000000000108  0000000000000000  AX       0     0     16
  [ 3] .rela.text        RELA             0000000000000000  00000178
       0000000000000108  0000000000000018          22     2     8
  [ 4] .init.text        PROGBITS         0000000000000000  00000280
       000000000000004c  0000000000000000  AX       0     0     1
  [ 5] .rela.init.text   RELA             0000000000000000  000002d0
       00000000000000c0  0000000000000018          22     4     8
  [ 6] .exit.text        PROGBITS         0000000000000000  00000390
       0000000000000025  0000000000000000  AX       0     0     1
  [ 7] .rela.exit.text   RELA             0000000000000000  000003b8
       0000000000000078  0000000000000018          22     6     8
  [ 8] .modinfo          PROGBITS         0000000000000000  00000430
       000000000000010a  0000000000000000   A       0     0     16
  [ 9] __param           PROGBITS         0000000000000000  00000540
       0000000000000020  0000000000000000   A       0     0     8
  [10] .rela__param      RELA             0000000000000000  00000560
       0000000000000048  0000000000000018          22     9     8
  [11] .rodata           PROGBITS         0000000000000000  000005c0
       0000000000000070  0000000000000000   A       0     0     32
  [12] .rela.rodata      RELA             0000000000000000  00000630
       0000000000000018  0000000000000018          22    11     8
  [13] __mcount_loc      PROGBITS         0000000000000000  00000648
       0000000000000018  0000000000000000   A       0     0     8
  [14] .rela__mcount_loc RELA             0000000000000000  00000660
       0000000000000048  0000000000000018          22    13     8
  [15] __versions        PROGBITS         0000000000000000  000006c0
       0000000000000300  0000000000000000   A       0     0     32
  [16] .data             PROGBITS         0000000000000000  000009c0
       000000000000003c  0000000000000000  WA       0     0     32
  [17] .rela.data        RELA             0000000000000000  00000a00
       0000000000000030  0000000000000018          22    16     8
  [18] .data..read_mostl PROGBITS         0000000000000000  00000a30
       0000000000000008  0000000000000000  WA       0     0     8
  [19] .gnu.linkonce.thi PROGBITS         0000000000000000  00000a40
       0000000000000238  0000000000000000  WA       0     0     32
  [20] .rela.gnu.linkonc RELA             0000000000000000  00000c78
       0000000000000030  0000000000000018          22    19     8
  [21] .bss              NOBITS           0000000000000000  00000ca8
       0000000000000000  0000000000000000  WA       0     0     4
  [22] .symtab           SYMTAB           0000000000000000  00000ca8
       00000000000004c8  0000000000000018          23    37     8
  [23] .strtab           STRTAB           0000000000000000  00001170
       000000000000028c  0000000000000000           0     0     1
  [24] .gnu_debuglink    PROGBITS         0000000000000000  000013fc
       000000000000001c  0000000000000000           0     0     4
  [25] .shstrtab         STRTAB           0000000000000000  00001418
       00000000000000ea  0000000000000000           0     0     1
フラグのキー:
  W (write), A (alloc), X (実行), M (merge), S (文字列), l (large)
  I (情報), L (リンク順), G (グループ), T (TLS), E (排他), x (不明)
  O (追加の OS 処理が必要) o (OS 固有), p (プロセッサ固有)

このファイルにはプログラムヘッダはありません。
```

セクション`[ 8] .modinfo` の詳細を確認。
（ここでは readelf を使っているが `objdump -s -j .modinfo iptable_filter.ko` などでも確認可能）

```sh
$ readelf -p 8 iptable_filter.ko

セクション '.modinfo' の文字列ダンプ:
  [     0]  parmtype=forward:bool
  [    16]  description=iptables filter table
  [    38]  author=Netfilter Core Team <coreteam@netfilter.org>
  [    6c]  license=GPL
  [    80]  srcversion=91D2BD9B036F1510ECEBFF9
  [    b0]  depends=ip_tables
  [    c2]  intree=Y
  [    cb]  vermagic=3.10.0-123.4.4.el7.x86_64 SMP mod_unload modversions
```

補足
----------------------------------------------------------------------

modinfo コマンドで確認できる情報には、上記 readelf で確認した項目に加え、`signer` `sig_key` `sig_hashlgo` などの項目が表示されている。

```sh
$ modinfo iptable_filter.ko
filename:       /lib/modules/3.10.0-123.4.4.el7.x86_64/kernel/net/ipv4/netfilter/iptable_filter.ko
description:    iptables filter table
author:         Netfilter Core Team <coreteam@netfilter.org>
license:        GPL
srcversion:     91D2BD9B036F1510ECEBFF9
depends:        ip_tables
intree:         Y
vermagic:       3.10.0-123.4.4.el7.x86_64 SMP mod_unload modversions
signer:         CentOS Linux kernel signing key
sig_key:        3C:8E:B1:41:98:F1:30:5E:0A:47:F9:27:3D:E9:AE:B3:11:FB:DF:59
sig_hashalgo:   sha256
parm:           forward:bool
```

これらの項目は、UEFI セキュアブートに関するものらしい。マルウェアなどがないセキュアな OSブートを実現するために、モージュルに署名がされている模様。

> modinfo ユーティリティーを使うと、カーネルモジュールの署名がある場合は、それについての情報を表示できます。このユーティリティーの使用方法については、「モジュール情報の表示」 を参照してください。
この追加された署名は ELF イメージセクションには含まれず、また ELF イメージの正式な一部ではないことに注意してください。このため、readelf のようなツールは、この署名をカーネルモジュールに表示することができません。

ref: https://access.redhat.com/documentation/ja-JP/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-signing-kernel-modules-for-secure-boot.html

なるほど。
