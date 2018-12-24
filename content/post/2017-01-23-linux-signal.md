---
title: "Linux シグナルの基礎"
date: 2017-01-23T14:36:22+09:00
tags:
- linux
url:            2017/01/23/linux-signal
thumbnailImage: 2017/01/23/linux-signal/linux-programming-interface.png
---

TLPI (The Linux Programming Interface) 再々。

TLPI の輪読の際に @matsumotory よりシグナルセットあたりをまとめるようにと指令が出たので、拙遅な感じでまとめました。

<!--more-->

## シグナルとは

プロセス間通信の一種。「プロセスにシグナルを送信すると、そのプロセスの正常処理に割り込んで、シグナル固有の処理(シグナルハンドラ) が実行される」プロセス側では、シグナルを受信した際の動作(シグナルハンドラ) を設定することや、シグナルをブロックすることも可能。

![](signal.png)

コンソールで、プロセスを終了させるために`kill -9 <PID>`とか`Ctrl+C`とかした際にも、対象プロセスにシグナルが送信されている。
ちなみに、PID「1」の init や systemd に`kill -9 1`しても何も起らない。(そういえば昔、oom-killer に init を殺された覚えがあるな。勘違いだったか…)

## シグナルの主な特徴

- シグナルの状態
    - シグナルを送ることを「生成」といい、そのシグナルが処理されることを「配送」という。また、生成から配送まで間の状態を「保留」という
- シグナルの生成
    - シグナルは、別プロセスや自身からも送信可能だが主にカーネルから送られることが多い
    - シグナルは、プロセスだけでなく特定スレッドに対しても送信可能
- シグナルの配送
    - シグナルの種類によって、受信した際の標準の動作が決められている(SIGINTはプロセス終了、など)
    - シグナルを受信するプロセスは、シグナル受信時の動作を変更できる(シグナルハンドラの登録)
- シグナルの保留
    - シグナルを受信するプロセスは、特定のシグナルをブロック・アンブロックすることができる(ブロック中にきたシグナルはアンブロック時に配送される)


## シグナルの種類

シグナルには、古くからある「標準シグナル」と機能が追加された「リアルタイムシグナル」の 2種類がある。 シグナルには一意の整数(シグナル番号) が割り当てられていて、標準シグナルの場合は 1 から 32(NSIG) となっている。

```
[/usr/include/asm/signal.h]
 12 /* Here we must cater to libcs that poke about in kernel headers.  */
 13
 14 #define NSIG            32
 15 typedef unsigned long sigset_t;
 16
 17 #endif /* __ASSEMBLY__ */
 18
 19
 20 #define SIGHUP           1
 21 #define SIGINT           2
 22 #define SIGQUIT          3
 23 #define SIGILL           4
 24 #define SIGTRAP          5
 25 #define SIGABRT          6
 26 #define SIGIOT           6
 27 #define SIGBUS           7
 28 #define SIGFPE           8
 29 #define SIGKILL          9
 30 #define SIGUSR1         10
 31 #define SIGSEGV         11
 32 #define SIGUSR2         12
 33 #define SIGPIPE         13
 34 #define SIGALRM         14
 35 #define SIGTERM         15
 36 #define SIGSTKFLT       16
 37 #define SIGCHLD         17
 38 #define SIGCONT         18
 39 #define SIGSTOP         19
 40 #define SIGTSTP         20
 41 #define SIGTTIN         21
 42 #define SIGTTOU         22
 43 #define SIGURG          23
 44 #define SIGXCPU         24
 45 #define SIGXFSZ         25
 46 #define SIGVTALRM       26
 47 #define SIGPROF         27
 48 #define SIGWINCH        28
 49 #define SIGIO           29
 50 #define SIGPOLL         SIGIO
 51 /*
 52 #define SIGLOST         29
 53 */
 54 #define SIGPWR          30
 55 #define SIGSYS          31
 56 #define SIGUNUSED       31
 57
 58 /* These should not be considered constants from userland.  */
 59 #define SIGRTMIN        32
 60 #define SIGRTMAX        _NSIG
```

標準シグナルによってプロセスに伝えれらる情報は「シグナル番号」のみ。いつ、どこから何回受信したかと言った情報は伝えられない。 リアルタイムシグナルでは、こういった情報を伝えることができるようになっている。なお、リアルタイムシグナルには、標準シグナルのようなシグナル番号に対応すに名前(SIGHUP など)は定義されていない。

{{< alert info >}}
@n_soda さんにコメントいただいたので補足
```
プロセスに伝えれらる情報は「シグナル番号」のみ
```
上記の様に記載していますが、sigaction() に SA_SIGINFO フラグを指定することで、handler 実行時にシグナルを生成した pid, uid, フォルト時のアドレスなどを含む、siginfo_t を受け取ることは可能です。
{{< /alert >}}

## シグナルの生成

プロセスからシグルナルを送信する場合は、以下のようなシステムコールや glibc の関数を用いる。


システムコール・関数|用途
:--|:--
kill()|プロセスにシグナルを送信
pthread_kill()|スレッドにシグナルを送信
raise()|自身にシグナルを送信
killpg()|プロセスグループにシグナルを送信

また、ハードウェアや端末契機でもシグナルは送られてくる。

- ハードウェア例外
   - `SIGFPE` : 0 除算
   - `SIGSEGV` : メモリアクセス違反
- 端末へキー入力
   - `SIGINT` : Ctrl+C が入力された
   - `SIGQUIT` : Ctrl+\ が入力された
- ソフトウェアイベント
   - `SIGCHLD` : 子プロセスが終了した
   - `SIGXCPU` : CPU の利用上限に達した (ハードリミットではSIGKILL)
   - `SIGIO` : fd からデータが読み取れる状態になった


## シグナルの配送

シグナルが配送されると、プロセスの通常処理に割り込んで、シグナルハンドラが実行される。

シグナル種類ごとにデフォルトの動作が決められており、個別にシグナルハンドラを登録していなければ、そのデフォルトの動作がカーネルにより実行される。デフォルトの動作は以下の５つ。

1. プロセスを終了する
1. コアを出力し、プロセスを終了する
1. シグナルを無視する
1. 処理を一時停止する
1. 処理を再開する

シグナルハンドラは、以下どちらかの関数を使用してシグナル番号ごとに登録できる。signal より sigaction のほうが、機能や移植性から見ても有用なので、利用を推奨されているらしい。


- signal()

    ```
    void ( *signal(int sig, void (*handler)(int)) ) (int);
    ```
- sigaction()

    ```
    int sigaction(int sig, const struct sigaction *act, struct sigaction *oldact);
    ```
    引数 act の型である sigaction 構造体は、以下のようになっている。
    ```
    struct sigaction {
        void (*sa_handler)(int);
        sigset_t sa_mask;
        int sa_flags;
        void (*sa_restorer)(void);
    };
    ```
    1 つ目のメンバである`sa_handler`は signal() の引数`handler`と同様にシグナルハンドラを表す。
    2 つ目のメンバである`sa_mask`はハンドラ実行中にブロックしたいグナルを指定する。ブロックしたいシグナルが複数ある場合もあるので、複数のシグナルを表すことができるシグナル

## シグナルセット

シグナルセットは、複数のシグナルをまとめて表現するもの。どのシグナルが選択されているかを表すだけなので、Linux では以下のような整数型で実装されており、各ビットの位置がシグナル番号に対応する。

```
[/usr/include/asm/signal.h]
typedef unsigned long sigset_t;
```

プロセスがどのシグナルをブロックしているかは /proc/PID/status を見るとわかる(下記は 64bit 環境)。 bash を例にすると、
```
# grep ^SigBlk /proc/$$/status
SigBlk: 0000000000010000
```
SigBlk の値がブロックしているシグナルを表していて、これは16進表記になっているので、2進表記にすると以下のようになる。
```
# ruby -e 'printf("%064b\n",0x0000000000010000)'
0000000000000000000000000000000000000000000000010000000000000000
```
つまり、17bit 目にビットが立っているので、上に記載した「シグナルの種類」を見ると、シグナル番号 17 つまり、SIGCHLD のみブロックしていることがわかる。

{{< alert warning >}}
記事公開時、SigBlk を紹介するところを誤って SigIgn の例を記載していたため、修正しました。
{{< /alert >}}

ただ、Linux の実装がビットマスク使用しているだけなので、シグナルマスクを操作する場合は、必ず以下の関数を用いる必要がある。

関数|用途
:--|:--
sigemptyset|すべてシグナルが選択されていない状態に初期化する
sigfillset|すべてシグナルが選択されている状態に初期化する
sigaddset|シグナルセットに一つのシグナルを追加する
sigdelset|シグナルセットから一つのシグナルを削除する
sigismember|シグナルセットに特定のシグナルが含まれているか調べる
sigandset|シグナルセットに指定した sigset_t とAND した結果を設定する
sigorset|シグナルセットに指定した sigset_t とOR した結果を設定する
sigisemptyset|シグナルセットが空かどうかしらべる


## シグナルの保留

シグナルが「生成」され、該当のプロセスが次に実行されたタイミングで、シグナルは「配送」される。この生成から配送までの間の状態を「保留」という。

![](signal-life.png)

保留の状態は、スケジュール待ちの場合だけでなく、プロセス自身でシグナルをブロックすることでも発生する。

さきほど説明した sigaction() では、シグナルセットを使用してシグナルのブロックを指示することができた。ただ、これは、シグナルハンドラ実行中のみブロックされており、ハンドラが終了すると自動的に解除（アンブロック）される。

そのため、 明示的にブロック・アンブロックしたい場合は、sigprocmask(), pthread_sigmask() を使用する。

## シグナルマスク

ブロックしているシグナルは「シグナルマスク」というプロセス（正しくはスレッド）の属性で管理されており、以下のようなタイミングで操作される。

- シグナルが配送された際、下記シグナルをシグナルマスクに追加し、シグナルハンドラが完了するとシグナルマスクから自動的に削除する
    - 受診した該当のシグナル（sigaction で変更可能）
    - sigaction で指定したブロックしたいグナルセットのシグナル
- sigprocmask(), pthread_sigmask() が実行されたタイミング
    - 引数に SIG_BLOCK が指定されると追加、SIG_UNBLOCK が指定されると削除される

## ブロック中のシグナル

ブロック中のシグナルが生成されると、カーネルはシグナルを保留シグナルに追加し、該当のシグナルがアンブロックされるまで配送しない。また、ブロック中に同じシグナル番号のシグナルが複数回生成されても、アンブロック時には一度しか配送されない。

保留シグナルは、ブロックシグナル（SigBlk）と同様に /proc/PID/status で確認できる。

```
# sleep 10 &
[1] 21577
#
# kill -STOP 21577
# kill -USR1 21577
# grep ^ShdPnd /proc/21577/status
SigPnd: 0000000000000200
#
# ruby -e 'printf("%064b\n",0x0000000000000200)'
0000000000000000000000000000000000000000000000000000001000000000
```

sleep コマンドを STOP し、SIGUSR1 を送っている。STOP しているのでシグナル(SIGUSR1)が配送されず、保留状態となっている。

なお、SIGKILL、SIGSTOP をブロックしようとしても無視され、エラーにもならない。

## シグナル処理時のカーネルの動作

(本当は、ここの内容をメインにしたかったが、概要を書いただけで力尽きたので、次回書く。)

