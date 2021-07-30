---
title: "SSHが切れた時、実行中のプロセスはどうなるか?"
date: 2021-07-30T02:02:20+09:00
tags:
  - linux
slug:           2021/07/30/process-on-termainal
thumbnailImage: 2021/07/30/process-on-termainal/bash.png
---

毎週行っているインフラチャプターの集まりで、下のような質問があって、
自分も曖昧な回答しかできなかったので、調べてみた。
> SSH で、長時間かかるコマンドを実行中に、ターミナルの接続が切れてもプロセスが
> 生きてるのはなぜ？

<!--more-->

環境
-----------------------------------------------------------------------------------

macOS 上の multipass で検証。

```
Description: Ubuntu 20.04.2 LTS
kernel: 5.4.0-77-generic
bash: 5.0.17
```

親が死んだら init が回収する
-----------------------------------------------------------------------------------

SSH の時の動作を確認をする前に、通常、親プロセスが終了した時の話。

↓みたいな親子関係にあるプロセス内、親の方（PID=8073）を kill してみると、

```shell
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
   8073    8064 S    ./fork
   8074    8073 S     \_ ./fork
$
$ kill 8073     # 親プロセスを kill
```
子プロセス（PID=8074）の親は、initに変わる（PPID:8073→1）。
```shell
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
   8074       1 S    ./fork    # 子プロセスの親がinitに代わった（PPID=1）
```

つまり「親が死んだら、init が親になってくれる」。

通常、親プロセスは、wait() などを使用して、終了した子プロセスの「終了ステータス」や
「消費したリソース情報」を取得する必要がある。しかし、親が死んでいると、子の情報を
受け取ってくれる人がいないため、init が親代りになってくれているんだと思う。面倒見がよい。


SSH接続時の場合
-----------------------------------------------------------------------------------

上に書いたように、init が子プロセスを回収するなら、SSH の接続が切れた際も同様の動きに
なりそうだが、実際はそうはならない（接続が切れたタイミングでプロセスが死ぬことがある）。

これは、SSHなどで使われる「制御端末（pts・tty）」と「制御プロセス（bash etc）」の
動作に起因している。確認した動作を簡単にまとめると、

接続が切れた時、
1. kernelからbash（制御プロセス）に SIGHUP が送られる
1. bash はフォアグランドプロセスに SIGHUP 送り、バックグランドプロセスへは何もしない
1. ただし、STOP されているプロセスに対しては、SIGCONT で再開後、SIGTERM を送る


動作まとめ
-----------------------------------------------------------------------------------
つまり、端末上のプロセスは、状態（フォアかバックか、STOPかRUNNNINGか、など）によって、
接続が切れた際の結果が、以下のようになる。

　|端末上のプロセスの状態|SIGHUPの無視|切断後の状態
--|--|--|--
A|フォアグラウンド|なし|プロセス終了
B|フォアグラウンド|あり|init が回収
C|バックグラウンド|なし|init が回収
D|バックグラウンド|あり|init が回収
E|STOPされている|なし|プロセス終了
F|STOPされている|あり|プロセス終了

なお、SIGHUP を受けた時の動作によって結果が変わるので、SIGHUP を無視してるかどうかで
パターン分けしている。よく使われる nohup コマンドは、この SIGHUP を 無視 してくれるやつ。



付録A. nohup
-----------------------------------------------------------------------------------

nohup から起動されたコマンドが、SIGHUP を無視 していることは、proc 配下の
status を見るとわかる。

nohup ありなしで sleep を起動して、

```shell
$ sleep 100 &
[1] 37008
$ nohup sleep 100 &
[2] 37010
```

それぞれの status を見ると、nohup で起動された方は、SigIgn の値が 1 になっている。
この値が、どのシグナルに対応しているかは、以前の記事（[Linuxシグナルの基礎]）を
ご参考に :-)

```shell
$ grep SigIgn /proc/37008/status
SigIgn:	0000000000000000
$ grep SigIgn /proc/37010/status
SigIgn:	0000000000000001
```

付録B. huponexit
-----------------------------------------------------------------------------------

huponexit はシェルのオプションで、シェルの終了時にバックグランドプロセスに対して、
SIGHUP は送るかどうか。

デフォルトは off。なので、上のまとめ様な結果になる。

```
$ shopt huponexit
huponexit      	off
```

これを on にする（-s）と、バッググランドプロセスに対しても SIGHUP が送られる。
off にする場合は、-u。

```
$ shopt -s huponexit
$ shopt huponexit
huponexit      	on
$
$ shopt -u huponexit
$ shopt huponexit
huponexit      	off
```

付録C. disown
-----------------------------------------------------------------------------------

nohup を忘れた時は、基本バックグランドに回せばログアウト後もプロセスは残るが、
huponexit が有効だと、バックグランドでも SIGHUP を受けてしまう。

その場合は、シェルの組込コマンドである disown を使う。  
これは、SIGHUP を無視するようなものではなく、指定したジョブグループをジョブの一覧から
外すコマンド。ジョブの一覧から外れると、シェルは SIGHUP を送らなくなる。

sleep をバックグランドで起動し、ジョブにいることを確認。

```shell
$ sleep 100 | sleep 100 &
[1] 37306
$ jobs -l
[1]+ 37305 Running                 sleep 100
     37306                       | sleep 100 &
```

disown すると、ジョブの一覧からいなくなるが、プロセスとしては存在している。

```
$ disown 37306
$ jobs -l
$
$ ps -C sleep u
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
ubuntu     37305  0.0  0.0   7228   580 pts/2    S    01:42   0:00 sleep 100
ubuntu     37306  0.0  0.0   7228   528 pts/2    S    01:42   0:00 sleep 100
$
```
これで、huponexit が設定されていても、ログアウトで消えない。

付録Z. zombie process
-----------------------------------------------------------------------------------

子プロセスが死んだ時、親が終了ステータスなどの情報を受け取らないと、子供はゾンビに
なってしまう。

```
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
   7299    7241 S    ./fork
   7300    7299 S     \_ ./fork
$
$ kill 7300
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
   7299    7241 S    ./fork
   7300    7299 Z     \_ [fork] <defunct> 🧟
```

ゾンビは root で kill しても存在し続けるが、
```
$ sudo kill -9 7300
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
   7299    7241 S    ./fork
   7300    7299 Z     \_ [fork] <defunct>
```

親を殺すと一緒にいなくなる。なむ。
```
$ kill 7299
$
[1]+  Terminated              ./fork
$ ps -C fork -o pid,ppid,stat,command f
    PID    PPID STAT COMMAND
$
```

 
<!--links-->
[Linuxシグナルの基礎]: https://harasou.jp/2017/01/23/linux-signal/
