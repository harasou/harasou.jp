---
title: "continue: only meaningful in a `for', `while', or `until' loop"
date: 2021-02-11T09:21:23+09:00
tags:
  - linux
slug:           2021/02/11/bash-continue-error
thumbnailImage: 2021/02/11/bash-continue-error/bash.png
---

以前から使い回していたシェルスクリプトが、continue 時にエラーが出るようになった。

<!--more-->

```
#!/bin/bash

for i in 1 2 3
do
    {
        [ $i -eq 2 ] && continue
        echo $i
    } 2>&1 | tee $i.log
done
```

forループで受け取った値ごとにログを吐きたかったのだが、continue するとエラーになる😓
処理も継続されてるし...

```
# bash loop.sh
1
loop.sh: line 6: continue: only meaningful in a `for', `while', or `until' loop
2
3
```

原因は subshell
-----------------------------------------------------------------------------------

原因は、サブシェルの中で continue してたから（pipe 使ってるので `{}` でもサブシェルになる）。
ただ、以前使っていた bash4系？だとエラーにならない。

```
$ bash --version
GNU bash, version 4.3.48(1)-release (x86_64-pc-linux-gnu)

$ bash loop.sh
1
3
```

今回エラーになったバージョンは以下。処理をコンテナでやるようになって、バージョンが上がったことで
非互換が出たみたい。

```
# bash --version
GNU bash, version 5.0.3(1)-release (x86_64-pc-linux-gnu)
```

対処
-----------------------------------------------------------------------------------

`{}` 中で色々な処理をやってるので、それぞれの処理でログ吐くのはめんどくさい。

プロセス置換 `>()` や `exec` 使って、出力先を変えようと試してみたけど、うまくいかなかった。
コマンドが入力待ちになったり、ログの中身が変になったり。

```
#!/bin/bash

for i in 1 2 3
do
    {
        [ $i -eq 2 ] && continue
        echo $i
    } > >(tee $i.log) 2>&1
done
```
```
#!/bin/bash

for i in 1 2 3
do
    exec > >(tee $i.log)
    exec 2>&1

    [ $i -eq 2 ] && continue
    echo $i
done
```
結局、サブシェルの外で continue することに。もっとシンプルな方法はないんだろうか...
```
#!/bin/bash

SKIP_CODE=127
for i in 1 2 3
do
    {
        [ $i -eq 2 ] && exit $SKIP_CODE
        echo $i
    } 2>&1 | tee $i.log

    [ ${PIPESTATUS[0]} -eq $SKIP_CODE ] && continue

    # skip しない時に必要な処理
done
```



<!--links-->
