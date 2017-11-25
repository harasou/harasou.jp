---
title: "cgroup による oom-killer の状態を eventfd 経由で受け取る"
date: 2015-05-20T21:30:05+09:00
tags:
  - cgroup
slug: 2015/05/20/cgroup-eventfd
---

cgroup の通知API
----------------------------------------------------------------------
cgroup の memory サブシテムを利用すると、登録したプロセスがメモリを使いすぎた際、oom-killer が動作し、対象プロセスを kill することができる（デフォルト動作)。

kill されたことは syslog など見ればわかるが、cgroup には`通知API`といった機能があり、アプリ側で oom-killer が動作した際のイベントを受け取ることが可能なので、この機能を試してみる。

<!--more-->


通知を受け取るための流れ
----------------------------------------------------------------------
1. eventfd を生成する
1. `生成した eventfd`と`memory.oom_control`のファイルディスクリプタを、`cgroup.event_control` に書き込む
1. イベントを受け取るアプリ側で、生成した eventfd を`read()`する
1. cgroup に登録したプロセスが制限以上のメモリを使用すると oom-killer が動作し、eventfd に状態が書き込まれる
1. アプリ側では、`read()`していた処理が戻ってくるので、その値から何かしらの処理を行う

### サンプル
source にすると以下のような感じ。

```c oom-notify.c
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/eventfd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static inline void die(const char *msg) {
    fprintf(stderr, "error: %s: %s(%d)\n", msg, strerror(errno), errno);
    exit(EXIT_FAILURE);
}
static inline void usage(void) {
    fprintf(stderr, "usage: oom_eventfd_test <cgroup.event_control> <memory.oom_control>\n");
    exit(EXIT_FAILURE);
}

#define BUFSIZE 256

int main(int argc, char *argv[])
{
    char buf[BUFSIZE];
    int efd, cfd, ofd, rb, wb;
    uint64_t u;

    if (argc != 3)
        usage();

    if ((efd = eventfd(0, 0)) == -1)
        die("eventfd");

    if ((cfd = open(argv[1], O_WRONLY)) == -1)
        die("cgroup.event_control");

    if ((ofd = open(argv[2], O_RDONLY)) == -1)
        die("memory.oom_control");

    if ((wb = snprintf(buf, BUFSIZE, "%d %d", efd, ofd)) >= BUFSIZE)
        die("buffer too small");

    if (write(cfd, buf, wb) == -1)
        die("write cgroup.event_control");

    if (close(cfd) == -1)
        die("close cgroup.event_control");

    for (;;) {
        if (read(efd, &u, sizeof(uint64_t)) != sizeof(uint64_t))
            die("read eventfd");

        printf("mem_cgroup oom event received \n");
    }

    return 0;
}
```
第１引数で渡された `memory.oom_control` のパスからファイルディスクリプタを取得し、作成した eventfd  のファイルディスクリプタと合わせた文字列を、第２引数のファイル`cgroup.event_control`に書き込んでいる。


### evnetfd とは
eventfd は、kernel 2.6.22 から追加されたファイルディスクリプタの一種で、上記のように`eventfd(2)`で作成する。

http://linuxjm.osdn.jp/html/LDP_man-pages/man2/eventfd.2.html

アプリケーションは、作成したファイルディスクリプタ経由で、通知したり、通知を待ったりすることができるが、やりとりできる情報は 8バイトの整数値のみとなっている。


動作確認
----------------------------------------------------------------------
動作API による oom-killer の通知を試してみる。

### 準備

1. test cgroups を作成し、自身の pid を登録（ここから生成する子プロは全て同じ制限を受ける）

    ```
    mkdir /sys/fs/cgroup/memory/test
    echo $$ > /sys/fs/cgroup/memory/test/tasks
    ```

1. イベント受信用のプログラムを別セッションから起動

    ```
    make oom-notify
    ./oom-notify /sys/fs/cgroup/memory/test/cgroup.event_control /sys/fs/cgroup/memory/test/memory.oom_control
    ```

### パターン１「memory.oom_control = 0」
oom-killer を有効化した状態でテスト

1. test cgroup で 10M byte の制限を実施

    ```
    echo 10M > /sys/fs/cgroup/memory/test/memory.limit_in_bytes
    echo 10M > /sys/fs/cgroup/memory/test/memory.memsw.limit_in_bytes
    ```

1. 「準備 1」のセッションから、1M 近くメモリを消費するコマンドを実行

    ```
    [root@localhost DEV]# dd if=/dev/zero bs=1024 count=1024 | read a
    1024+0 records in
    1024+0 records out
    1048576 bytes (1.0 MB) copied, 0.23278 s, 4.5 MB/s
    ```
    10M 許可されているので、正常に完了する。
    ```
    [root@localhost DEV]# ./oom-notify /sys/fs/cgroup/memory/test/cgroup.event_control /sys/fs/cgroup/memory/test/memory.oom_control
    ```
    イベントは何も受け取っていない

1. test cgroup の制限を 1M byte に変更し、同様のコマンドを実行    

    ```
    echo 1M > /sys/fs/cgroup/memory/test/memory.limit_in_bytes
    echo 1M > /sys/fs/cgroup/memory/test/memory.memsw.limit_in_bytes
    ```
    ```
    [root@localhost DEV]# dd if=/dev/zero bs=1024 count=1024 | read a
    Killed
    ```
    oom-killer が動作し、kill される。kill されたタイミングで、イベントを受信。
    ```
    [root@localhost DEV]# ./oom-notify /sys/fs/cgroup/memory/test/cgroup.event_control /sys/fs/cgroup/memory/test/memory.oom_control
    mem_cgroup oom event received
    ```

### パターン２「memory.oom_control = 1」
oom-killer を無効化した状態でテスト。無効化した状態では、タスクが制限値以上のメモリを使用すると停止させられる。メモリを取得できる状態になると（メモリが空くか、制限値が大きくすると）処理が再開する。

1. oom-killer を無効化

    ```
    echo 1 > /sys/fs/cgroup/memory/test/memory.oom_control
    ```
    ```
    [root@localhost DEV]# cat /sys/fs/cgroup/memory/test/memory.oom_control
    oom_kill_disable 1
    under_oom 0
    ```
    `oom_kill_disable` が 1 になる

1. 「準備 1」のセッションから、1M 近くメモリを消費するコマンドを実行

    ```
    [root@localhost DEV]# dd if=/dev/zero bs=1024 count=1024 | read a
    
    ```
    実行すると処理は完了せず停止させられる。停止したタイミングで、イベントを受信。この時`memory.oom_control` の under_oom は 1 になる。なお、ps で確認しても、プロセスの状態は T ではない。
    ```
    [root@localhost DEV]# ./oom-notify /sys/fs/cgroup/memory/test/cgroup.event_control /sys/fs/cgroup/memory/test/memory.oom_control
     :
    mem_cgroup oom event received
    ```
    ```
    [root@localhost DEV]# cat /sys/fs/cgroup/memory/test/memory.oom_control
    oom_kill_disable 1
    under_oom 1
    ```
    ```
    [root@localhost DEV]# ps uf
    USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
     :
    root      3490  0.0  0.5 188764  2696 pts/0    S    03:42   0:00 sudo -s
    root      3491  0.0  0.4 115512  2100 pts/0    S    03:42   0:00  \_ /bin/bash
    root     12988  0.0  0.0   4340   312 pts/0    D+   08:18   0:00      \_ dd if=/dev/zero bs=1024 count=1024
    root     12989  0.5  0.2 116084  1296 pts/0    D+   08:18   0:00      \_ /bin/bash
    ```

1. test cgroup の制限値を大きくする（1M -> 10M）

    ```
    echo 10M > /sys/fs/cgroup/memory/test/memory.memsw.limit_in_bytes
    ```

    処理が再開され、正常に完了する。`memory.oom_control`の under_oom は 0 に戻る。イベントの受信はなし。
    ```
    [root@localhost DEV]# dd if=/dev/zero bs=1024 count=1024 | read a
    1024+0 records in
    1024+0 records out
    1048576 bytes (1.0 MB) copied, 82.5348 s, 12.7 kB/s
    ```
    ```
    [root@localhost DEV]# cat /sys/fs/cgroup/memory/test/memory.oom_control
    oom_kill_disable 1
    under_oom 0
    ```
