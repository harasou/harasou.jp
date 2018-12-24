---
title: "Linuxでのサマータイム - JDTの来襲"
date: 2018-08-12T13:48:25+09:00
tags:
  - linux
url:            2018/08/12/japan-daylight-saving-time
thumbnailImage: 2018/08/12/japan-daylight-saving-time/blackclock.png
draft: false
---

最近、サマータイム導入の話で盛り上がっているので、Linux ではどうなっているのか調べてみた。

<!--more-->

JDT（Japan Daylight Saving Time）って知ってる？
-----------------------------------------------------------------------------------

70年前の今日、日本は`JST` ではなく`JDT`だった。

```
$ date --date="70 years ago"
Thu Aug 12 06:10:32 JDT 1948
```

`JDT` というのは、Japan Daylight Saving Time のことで、つまり、日本の夏時間。

日本でも 1948年から1951年の4年間、サマータイムが導入されていたので、
サマータイム中の日本の表示時刻は、普段よく目にする `JST` ではなく`JDT` になっている。

（実際は Epoch以前の話なので、当時、使われたことはないと思う:-）


カーネルの時間
-----------------------------------------------------------------------------------

カーネルは、何月何日と言った情報は持っていない。

管理しているのは Epoch（UTC 1970/1/1 0:00）からの経過時間（timekeeper->xtime_sec,
xtime_nsec）だけ。
VFS の inode構造体のメンバ（inode->i_atime, i_mtime, i_ctime）なんかも同様。

このため、うるう秒の対応とは違い、サーマタイムが終わるときに、カーネル内の時間が
戻ったりすることはない。


サマータイムで時刻が進む？戻る？
-----------------------------------------------------------------------------------

ではサマータイムで時刻が、進むだの、戻るだのと言ってるのは何かというと、
カーネルが管理している値を、「可読可能は文字列」にしたときに時刻が進んだり
戻ったりするように見えるから（この辺りは glibc の仕事）。

試しにサマータイムに切り替わる直前のシステムを再現してみると、以下のような出力になる。

```
$ sudo ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime
$ sudo date -s "Sun Mar 11 01:59:00 2018"
$ while :; do date "+[%s] %c %Z"; sleep 1; done
  :
[1520762397] Sun Mar 11 01:59:57 2018 PST
[1520762398] Sun Mar 11 01:59:58 2018 PST
[1520762399] Sun Mar 11 01:59:59 2018 PST
[1520762400] Sun Mar 11 03:00:00 2018 PDT <- PST から PDT(夏時間)に変わった
[1520762401] Sun Mar 11 03:00:01 2018 PDT
[1520762402] Sun Mar 11 03:00:02 2018 PDT
```

経過時間 `%s` は変わりなく 1秒づつ増え続けているが、ローカル時間`%c`は、夏時間に
変わったタイミングで 1時間進んでいる。
ただ、タイムゾーン`%Z` もちゃんと変更されているので、単純に時刻が進んだわけではない。

というわけで、時刻というのは、ローカル時間 + タイムゾーン という認識が重要。


どんな影響がでる？
-----------------------------------------------------------------------------------
2020年に日本でサマータイムが導入されると、どんな影響がでるか。

世界中で使われているような OS であれば、TZ（タイムゾーン）や DST（夏時間）の考慮が
されていると思うので、OSとしては問題ないと思う。ミドルウェアも多分大丈夫そう。

ただ、ミドルウェアの使い方やそれを利用するアプリが考慮できていないことは、
かなりある気がする。

### 例えば mysql の場合

mysql について軽く確認してみると、日付を保持する型として`TIMESTAMP`型や`DATETIME`型が
ある。`TIEMSTAMP`型は経過時間の情報なので問題なさそうだが、`DATETIME`型はタイムゾーンを
意識していないので、使っているアプリがあれば問題が出そう。

また、新しいタイムゾーンを反映するには、
[mysql_tzinfo_to_sql  を実行後、再起動を推奨][mysql_tzinfo_to_sql] しているので、ここでも
メンテが必要そうだ...

他にも、クラウド上の mysql を使ってると、アプリは JST だけど、mysql は UTC とかになっていて、
mysql の時刻系関数を使うと想定外の値になる、とかもあるかも。


サマータイムやタイムゾーンの定義
-----------------------------------------------------------------------------------
対応する必要も出てくるかもしれないので、OSの設定も確認しておく。

Linux では、/usr/share/zoninfo 配下に、TZ（タイムゾーン）や DST（Daylight Saving Time
夏時間）を定義するファイルが置かれていてる。

これらのファイルは、バイナリだが zdump を使うと中身を確認できる。

```
$ file /usr/share/zoneinfo/Asia/Tokyo
/usr/share/zoneinfo/Asia/Tokyo: timezone data, version 2, 3 gmt time flags, 3 std time flags, no leap seconds, 8 transition times, 3 abbreviation chars
$
$ zdump -v /usr/share/zoneinfo/Asia/Tokyo | grep -w 1948
/usr/share/zoneinfo/Asia/Tokyo  Sat May  1 14:59:59 1948 UTC = Sat May  1 23:59:59 1948 JST isdst=0 gmtoff=32400
/usr/share/zoneinfo/Asia/Tokyo  Sat May  1 15:00:00 1948 UTC = Sun May  2 01:00:00 1948 JDT isdst=1 gmtoff=36000
/usr/share/zoneinfo/Asia/Tokyo  Sat Sep 11 13:59:59 1948 UTC = Sat Sep 11 23:59:59 1948 JDT isdst=1 gmtoff=36000
/usr/share/zoneinfo/Asia/Tokyo  Sat Sep 11 14:00:00 1948 UTC = Sat Sep 11 23:00:00 1948 JST isdst=0 gmtoff=32400
```
これを見ると、冒頭の date コマンドで確認した内容が定義されていることがわかる。
つまり、2020年にもしサマータイムが導入されると、このファイルを更新する必要がある。

このバイナリファイルは zic（zone information compiler）というコマンドで、tzdata という
テキストファイルから生成可能。

```
$ file /usr/share/zoneinfo/tzdata.zi
/usr/share/zoneinfo/tzdata.zi: ASCII text
$
$ zic -d zoneinfo /usr/share/zoneinfo/tzdata.zi #zoneinfo配下に作成される
```
こんな感じ。


最後に
-----------------------------------------------------------------------------------
日本で、新たな夏時間の導入なんて、ほんとやめてほしい。


<!--links-->
[mysql_tzinfo_to_sql]: https://dev.mysql.com/doc/refman/5.6/ja/time-zone-support.html
[zic]: https://linuxjf.osdn.jp/JFdocs/TimePrecision-HOWTO/tz.html
