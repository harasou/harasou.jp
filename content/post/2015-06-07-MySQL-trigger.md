---
title: "MySQL のトリガで mruby を実行する"
date: 2015-06-07T02:06:30+09:00
tags:
  - mysql
  - mruby
slug: 2015/06/07/MySQL-trigger
---

先日会社で「mysql のテーブルと、プロセス上の共有メモリを連携させたい」って話が出たとき、トリガで外部プログラムが実行できればいけるのでは？と思ったので、調べてみた。

MySQL で外部コマンドを実行するには
----------------------------------------------------------------------
mysql で外部コマンドを実行するには `system` が使える。

```
mysql> system uname -a
Linux cent6 2.6.32-504.16.2.el6.x86_64 #1 SMP Wed Apr 22 06:48:29 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
```

ただ、これはターミナル上からとかでないと使えない。

調べてみると、mysql には UDF(User Defined Function) という仕組みがあって、自作関数を作成することができるらしい。これは、C や C++ で書いて共有ライブラリ(.so)を作成し、mysql の plugindir に放り込めば使えるようになる。

- [MySQL で UDF を定義しよう](http://aoking.hatenablog.jp/entry/20120824/1345778096)
- [はじめてのUDF](http://d.hatena.ne.jp/download_takeshi/20071124/1195915196)
- [やったーJavaScriptの動くMySQLできたよー](http://zentoo.hatenablog.com/entry/20110925/1316961032)

<!--more-->

結構情報はある。で、JavaScript が動くなら、golang とか mruby があるのでは？ってさがすとやはりあった。以下 mruby。

- [2012/05/12 やったーmrubyの動くMySQLできたよーAdd Star](http://mattn.kaoriya.net/software/lang/ruby/20120531210311.htm)
- [2015/05/01 MySQLでmrubyを動かす](http://blog.kentarok.org/entry/2015/05/01/014548)

さすが、mattn さん。しかも、なんともう一つの方はわれらが CTO の kentaro さん。

早速試してみる。kentaro さんのは、make 一発で mruby のコンパイルから plugin ディレクトリへのインストールまでやってくる便利設計。

ただ、今回は mruby に他の mrbgem 組み込んだりする予定なので、mattn さんのを使わせていただいた。


環境
----------------------------------------------------------------------
- CentOS6.6 (2.6.32-504.16.2.el6.x86_64)
- mruby 1.1.0 (2014-11-19)


準備
----------------------------------------------------------------------
1. mruby のコンパイル

    ```
    cd
    git clone https://github.com/mruby/mruby.git
    cd mruby
    ./minirake
    ```

1. mysql-mruby のコンパイル

    ```
    yum install -y gcc-c++ mysql-devel mysql-server
    cd
    git clone https://github.com/mattn/mysql-mruby.git
    cd mysql-mruby
    make
    g++ -I/usr/include/mysql  -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fno-strict-aliasing -fwrapv -fPIC   -DUNIV_LINUX -DUNIV_LINUX -DDBUG_OFF -fPIC -fpermissive -I../mruby/include -shared -Wall -g mrb_eval.cc -o mrb_eval.so -rdynamic -L/usr/lib64/mysql -lmysqlclient -lz -lcrypt -lnsl -lm -lssl -lcrypto ../mruby/build/host/lib/libmruby.a
    mrb_eval.cc: In function ‘char* mrb_eval(UDF_INIT*, UDF_ARGS*, char*, long unsigned int*, char*, char*)’:
    mrb_eval.cc:96: 警告: 符合付きと符合無しの整数式同士の比較です
    /usr/bin/ld: ../mruby/build/host/lib/libmruby.a(string.o): relocation R_X86_64_32 against `.rodata' can not be used when making a shared object; recompile with -fPIC
    ../mruby/build/host/lib/libmruby.a: could not read symbols: Bad value
    collect2: ld はステータス 1 で終了しました
    make: *** [all] エラー 1
    ```
    エラーが出た。`recompile with -fPIC` とのこと。

1. mruby のコンパイルやり直し

    ```
    cd ../mruby
    CFLAGS="-fPIC" ./minirake
    ```

1. mysql-mruby のコンパイル（再チャレンジ）

    ```
    cd ../mysql-mruby/
    make
    g++ -I/usr/include/mysql  -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fno-strict-aliasing -fwrapv -fPIC   -DUNIV_LINUX -DUNIV_LINUX -DDBUG_OFF -fPIC -fpermissive -I../mruby/include -shared -Wall -g mrb_eval.cc -o mrb_eval.so -rdynamic -L/usr/lib64/mysql -lmysqlclient -lz -lcrypt -lnsl -lm -lssl -lcrypto ../mruby/build/host/lib/libmruby.a
    mrb_eval.cc: In function 'char* mrb_eval(UDF_INIT*, UDF_ARGS*, char*, long unsigned int*, char*, char*)':
    mrb_eval.cc:96: warning: comparison between signed and unsigned integer expressions
    ```
    警告は出たけど、とりあえずコンパイルはできた。
    ```
    ll
    total 3652
    -rw-r--r-- 1 root root     347 Jun  5 02:07 Makefile
    -rw-r--r-- 1 root root     316 Jun  5 01:32 Makefile.msc
    -rw-r--r-- 1 root root    1538 Jun  5 01:32 README.md
    -rw-r--r-- 1 root root    3473 Jun  5 01:32 mrb_eval.cc
    -rwxr-xr-x 1 root root 3719282 Jun  5 04:40 mrb_eval.so
    ```

1. 作成された mrb_eval.so を plugin ディレクトリにコピー

    ```
    cp -v mrb_eval.so $(mysql_config --plugindir)/mrb_eval.so
    ```

1. mysqld の再起動

    ```
    /etc/init.d/mysqld restart
    ```


mrb_eval() を使ってみる
----------------------------------------------------------------------
1. 関数の作成

    ```
    mysql -uroot
    mysql> create function mrb_eval returns string soname 'mrb_eval.so';
    ```

1. 実行

    ```
    mysql> select mrb_eval('[1,2,3].map {|x| "hello#{x}"}');
    +-------------------------------------------+
    | mrb_eval('[1,2,3].map {|x| "hello#{x}"}') |
    +-------------------------------------------+
    | ["hello1", "hello2", "hello3"]            |
    +-------------------------------------------+
    1 row in set (0.01 sec)
    ```
    おお、実行された。


トリガとして使ってみる
----------------------------------------------------------------------
想定としては「テーブルのレコードが削除されたら、REST API 経由でアプリの共有メモリを削除する」というもの。

### 準備

1. mruby-simplehttp の組み込み
    とりあえず API が叩ければよいので、http clinet の機能を mruby に組み込む。あと、`PIC` もデフォルトで有効にしておく。

    ```
    cd ~/mruby
    vim build_config     # 下記 diff を参照
    ./minirake
    cd ~/mysql-mruby
    make
    cp -v mrb_eval.so $(mysql_config --plugindir)/mrb_eval.so
    /etc/init.d/mysql restart
    ```
    ```diff
    diff --git a/build_config.rb b/build_config.rb
    index 3408f19..ee149e9 100644
    --- a/build_config.rb
    +++ b/build_config.rb
    @@ -18,6 +18,11 @@ MRuby::Build.new do |conf|
       # conf.gem 'examples/mrbgems/c_and_ruby_extension_example'
       # conf.gem :github => 'masuidrive/mrbgems-example', :checksum_hash => '76518e8aecd131d047378448ac8055fa29d974a9'
       # conf.gem :git => 'git@github.com:masuidrive/mrbgems-example.git', :branch => 'master', :options => '-v'
    +  conf.gem :github => 'iij/mruby-io'
    +  conf.gem :github => 'iij/mruby-mtest'
    +  conf.gem :github => 'iij/mruby-pack'
    +  conf.gem :github => 'iij/mruby-socket'
    +  conf.gem :github => 'matsumoto-r/mruby-simplehttp'
    
       # include the default GEMs
       conf.gembox 'default'
    @@ -25,7 +30,7 @@ MRuby::Build.new do |conf|
       # C compiler settings
       # conf.cc do |cc|
       #   cc.command = ENV['CC'] || 'gcc'
    -  #   cc.flags = [ENV['CFLAGS'] || %w()]
    +  #   cc.flags = [ENV['CFLAGS'] || %w(-fPIC)]
       #   cc.include_paths = ["#{root}/include"]
       #   cc.defines = %w(DISABLE_GEMS)
       #   cc.option_include_path = '-I%s'
    ```

1. テスト用の table を作成
    
    ```
    cat <<SQL | mysql -uroot
    create database test;
    use test;
    create table members(id int, name varchar(20));
    insert into members values (1,"harasou1");
    insert into members values (2,"harasou2");
    insert into members values (3,"harasou3");
    select * from members;
    SQL
    ```

1. mruby を実行するトリガの作成

    ```
    DELIMITER //
    
    CREATE TRIGGER delete_mrb_eval AFTER DELETE ON members
    FOR EACH ROW
    BEGIN
      DECLARE result CHAR(255);
      DECLARE script CHAR(255);
      SET script = CONCAT('SimpleHttp.new("http","localhost").request("DELETE","/api/items/', OLD.id ,'",{"User-Agent" => "mruby-simplehttp"})');
      SET result = mrb_eval(script);
    END //
    
    DELIMITER ;
    ```

### テスト
nginx を localhost で実行した状態で、members テーブルのレコードを削除してみる。

1. レコードを１行削除

    ```
    mysql> delete from members where id = 2;
    Query OK, 1 row affected (0.02 sec)
    mysql>
    mysql> select * from members;
    +------+----------+
    | id   | name     |
    +------+----------+
    |    1 | harasou1 |
    |    3 | harasou3 |
    +------+----------+
    2 rows in set (0.00 sec)
    ```

1. ngix の access_log を確認

    ```
    [root@cent6 mysql-mruby]# tail /var/log/nginx/access.log
    127.0.0.1 - - [07/Jun/2015:00:29:28 +0900] "DELETE /api/items/2 HTTP/1.0" 405 172 "-" "mruby-simplehttp" "-"
    ```
    API や共有メモリ周りの処理は何も入れていないので 405 になっているが、ちゃんとアクセスは来ている。


まとめ
----------------------------------------------------------------------
トリガの細かい動きは調べられていないが、mysql のイベントを拾って mruby を実行することで、かなりいろんな処理ができそう。

mruby には、いろいろな package が公開されているので、がしがし使っていきたい。

http://www.mruby.org/libraries/
