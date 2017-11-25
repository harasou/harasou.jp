---
title: "mruby をさわってみた"
date: 2015-05-02T23:23:18+09:00
tags:
  - mruby
slug: 2015/05/02/mruby-faststep
---

mruby とは
----------------------------------------------------------------------
組込み向けに軽量化されたRuby。mruby 単体で実行するというよりは、組み込み機器や Cなどで書いたアプリのなかに、まるごと`mrubyアプリケーション+実行環境`を組み込んで利用する感じ。
![mruby](mruby.gif)

<!--more-->

mruby を MacOSX 上でコンパイル
---------------------------------------------------------------------
mruby をさわるため、まずソースからコンパイルする。コンパイルは拍子抜けするほど簡単。以下が必要だが、Command Line Tools をいれてれば足りる。

### 環境
- gcc
- ruby
- bision

### 手順
1. ソースのダウンロード([2fe556d](https://github.com/mruby/mruby/tree/2fe556d9c039839c20965a2c90dff703f04e40ec))

    ```sh
    git clone https://github.com/mruby/mruby
    cd mruby
    ```

1. コンパイル(速い)

    ```sh
    $ time ruby minirake
    (in /Users/PMAC051S/src/github.com/mruby/mruby)
    CC    src/array.c -> build/host/src/array.o
    CC    src/backtrace.c -> build/host/src/backtrace.o
     :
    real    0m14.238s
    user    0m8.442s
    sys 0m3.884s
    ```

コンパイルされたもの
----------------------------------------------------------------------
こんなファイルが出来る。

```sh
$ ls -l bin/* build/host/lib/libmruby.a
-rwxr-xr-x  1 harasou  staff   881116  5  2 18:27 bin/mirb*
-rwxr-xr-x  1 harasou  staff   656568  5  2 18:27 bin/mrbc*
-rwxr-xr-x  1 harasou  staff   920456  5  2 18:27 bin/mrdb*
-rwxr-xr-x  1 harasou  staff   879992  5  2 18:27 bin/mruby*
-rwxr-xr-x  1 harasou  staff   898124  5  2 18:27 bin/mruby-strip*
-rw-r--r--  1 harasou  staff  2027736  5  2 18:27 build/host/lib/libmruby.a
```

- mirb: mruby の irb
- mrbc: mruby スクリプトのコンパイラ。mrb 形式などを出力する。
- mrdb: mruby のデバッガ。
- mruby: mruby のインタプリンタ
- mruby-strip: ???
- libmruby.a: mruby のライブラリ

それぞれ使ってみた
----------------------------------------------------------------------
### mirb
irb の mruby 版

```ruby
$ bin/mirb
mirb - Embeddable Interactive Ruby Shell

> puts "Hello, World !"
Hello World !
 => nil
>
```

### mrbc
mruby スクリプトをデフォルトだと mrb 形式にコンパイルする。
mrb 形式というのは、mruby の独自フォーマットでプラットフォーム非依存。mrb 形式については、いずれ調査したい。

```sh
$ bin/mrbc --help
Usage: bin/mrbc [switches] programfile
  switches:
  -c           check syntax only
  -o<outfile>  place the output into <outfile>
  -v           print version number, then turn on verbose mode
  -g           produce debugging information
  -B<symbol>   binary <symbol> output in C language format
  -e           generate little endian iseq data
  -E           generate big endian iseq data
  --verbose    run at verbose mode
  --version    print the version
  --copyright  print the copyright
```
```sh
puts "Hello, world!"
```
```sh
$ bin/mrbc hello.rb
$ ls -l hello.*
-rw-r--r--  1 harasou  staff  103  5  2 23:37 hello.mrb
-rw-r--r--  1 harasou  staff   22  5  2 23:37 hello.rb
$ file hello.mrb
hello.mrb: data
$ od -tcx1 hello.mrb
0000000    R   I   T   E   0   0   0   3 022 372  \0  \0  \0   g   M   A
           52  49  54  45  30  30  30  33  12  fa  00  00  00  67  4d  41
0000020    T   Z   0   0   0   0   I   R   E   P  \0  \0  \0   I   0   0
           54  5a  30  30  30  30  49  52  45  50  00  00  00  49  30  30
0000040    0   0  \0  \0  \0   A  \0 001  \0 004  \0  \0  \0  \0  \0 004
           30  30  00  00  00  41  00  01  00  04  00  00  00  00  00  04
0000060   \0 200  \0 006 001  \0  \0   =  \0 200  \0 240  \0  \0  \0   J
           00  80  00  06  01  00  00  3d  00  80  00  a0  00  00  00  4a
0000100   \0  \0  \0 001  \0  \0  \r   H   e   l   l   o   ,       w   o
           00  00  00  01  00  00  0d  48  65  6c  6c  6f  2c  20  77  6f
0000120    r   l   d   !  \0  \0  \0 001  \0 004   p   u   t   s  \0   E
           72  6c  64  21  00  00  00  01  00  04  70  75  74  73  00  45
0000140    N   D  \0  \0  \0  \0  \b
           4e  44  00  00  00  00  08
0000147
```
```c
$ bin/mrbc -Bhello hello.rb
$ ll hello*
-rw-r--r--  1 harasou  staff  752  5  3 00:25 hello.c
-rw-r--r--  1 harasou  staff  103  5  2 23:37 hello.mrb
-rw-r--r--  1 harasou  staff   22  5  2 23:37 hello.rb
$ cat hello.c
/* dumped in little endian order.
   use `mrbc -E` option for big endian CPU. */
#include <stdint.h>
const uint8_t
#if defined __GNUC__
__attribute__((aligned(4)))
#elif defined _MSC_VER
__declspec(align(4))
#endif
hello[] = {
0x45,0x54,0x49,0x52,0x30,0x30,0x30,0x33,0x64,0x92,0x00,0x00,0x00,0x67,0x4d,0x41,
0x54,0x5a,0x30,0x30,0x30,0x30,0x49,0x52,0x45,0x50,0x00,0x00,0x00,0x49,0x30,0x30,
0x30,0x30,0x00,0x00,0x00,0x41,0x00,0x01,0x00,0x04,0x00,0x00,0x00,0x00,0x00,0x04,
0x06,0x00,0x80,0x00,0x3d,0x00,0x00,0x01,0xa0,0x00,0x80,0x00,0x4a,0x00,0x00,0x00,
0x00,0x00,0x00,0x01,0x00,0x00,0x0d,0x48,0x65,0x6c,0x6c,0x6f,0x2c,0x20,0x77,0x6f,
0x72,0x6c,0x64,0x21,0x00,0x00,0x00,0x01,0x00,0x04,0x70,0x75,0x74,0x73,0x00,0x45,
0x4e,0x44,0x00,0x00,0x00,0x00,0x08,
};
```
C形式はどうやって使うのかも不明なので今度調べる。`mrb_read_irep(mrb, hello)` で読み込む？

### mruby
mruby のインタプリンタ。mrb形式のファイルを渡す場合は、`-b` オプションで。

```sh
$ bin/mruby -b hello.mrb
Hello, world!
```

### libmruby.a
Cから利用する際のライブラリ。

```c
#include <mruby.h>
#include <mruby/compile.h>

int main(void) {
    mrb_state* mrb;
    mrb = mrb_open();
    mrb_load_string(mrb,"puts 'Hello World!'");
    mrb_close(mrb);

    return 0;
}
```
```sh
$ gcc -o hello -Iinclude hello.c build/host/lib/libmruby.a
$ ./hello
Hello World!
```
ちなみにアーカイブに入っていたオブジェクトファイルは以下のような感じだった。
```sh
$ ar t build/host/lib/libmruby.a
__.SYMDEF SORTED
array.o
backtrace.o
class.o
codegen.o
compar.o
crc.o
debug.o
dump.o
enum.o
error.o
etc.o
fmt_fp.o
gc.o
hash.o
init.o
kernel.o
load.o
numeric.o
object.o
pool.o
print.o
proc.o
range.o
state.o
string.o
symbol.o
variable.o
version.o
vm.o
y.tab.o
mrblib.o
kernel.o
sprintf.o
gem_init.o
print.o
gem_init.o
math.o
gem_init.o
time.o
gem_init.o
struct.o
gem_init.o
gem_init.o
string.o
gem_init.o
numeric_ext.o
gem_init.o
array.o
gem_init.o
hash-ext.o
gem_init.o
range.o
gem_init.o
proc.o
gem_init.o
symbol.o
gem_init.o
mt19937ar.o
random.o
gem_init.o
object.o
gem_init.o
mruby_objectspace.o
gem_init.o
fiber.o
gem_init.o
gem_init.o
gem_init.o
gem_init.o
kernel.o
gem_init.o
gem_init.o
```

### mrbd
デバッガ。gdb と似たような感じ。

```
$ bin/mrdb hello.rb
(hello.rb:1) help
Commands
  b[reak] -- Set breakpoint
  c[ontinue] -- Continue program being debugged
  d[elete] -- Delete some breakpoints
  dis[able] -- Disable some breakpoints
  en[able] -- Enable some breakpoints
  ev[al] -- Evaluate expression
  h[elp] -- Print this help
  i[nfo] b[reakpoints] -- Status of breakpoints
  l[ist] -- List specified line
  p[rint] -- Print value of expression
  q[uit] -- Exit mrdb
  r[un] -- Start debugged program
  s[tep] -- Step program until it reaches a different source line
```
