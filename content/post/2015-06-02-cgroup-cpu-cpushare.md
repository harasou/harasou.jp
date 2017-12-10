---
title: "cgroup の cpu.shares を検証した"
date: 2015-06-02T04:09:33+09:00
update: 2015-06-03 04:09:33
tags:
  - cgroup
slug: 2015/06/02/cgroup-cpu-cpushare
---

cgroup には複数のサブシステム（controller）があるが、その中の `cpu.shares` について検証してみた。

cpu.shares とは
----------------------------------------------------------------------
cpu.shares を設定すると、タスクが使用できる CPU 時間の`割合`を変更することができる。

具体的に言うと、`A` `B`２つのグループを作り、cpu.shares をそれぞれ`1024` `2048`とした場合、B のグループにいるプロセスが、A のグループにいるプロセスより 2倍 CPU を使えるようになる。以下、実行例。

<!--more-->

```sh
# mkdir /cgroup/{A,B}
# echo 1024 > /cgroup/A/cpu.shares
# echo 2048 > /cgroup/B/cpu.shares
# sh -c "while : ; do : ; done" & echo $! > /cgroup/A/tasks
[1] 2835
# sh -c "while : ; do : ; done" & echo $! > /cgroup/B/tasks
[2] 2836
# ps uf
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root      2816  0.0  0.5 175140  2656 pts/2    S    21:44   0:00 sudo -s
root      2817  0.0  0.3 108300  1908 pts/2    S+   21:44   0:00  \_ /bin/bash
root      2835 34.9  0.2 106056  1268 pts/2    R    21:47   0:56      \_ sh -c while : ; do : ; done
root      2836 66.1  0.2 106056  1268 pts/2    R    21:47   1:43      \_ sh -c while : ; do : ; done
```

グループ B に登録した PID:2836 のプロセスが、グループ A に登録した PID:2835 の 2倍 CPU を使用している。


今回の疑問点
----------------------------------------------------------------------

これだけなら、わかりやすいが、以下の点が不明だったので実際に検証してみた。

- グループ内に複数プロセスがいる場合どのように CPU が割り振られるのか
- ルートグループに属するプロセスの CPU の割り振りはどうなるか


環境
----------------------------------------------------------------------
- マシン: Vagrant(CPU コア1)
- OS:
    - CentOS6.6 (2.6.32-504.16.2.el6.x86_64)
    - CentOS7.1 (3.10.0-229.el7.x86_64)

- 今回検証したグループ構成

    ![](cgroup.png)
    - CPU のルートグループ配下に `test` グループを作成する
    - test グループ配下に、`A` `B` `C` グループを作成する
    - 作成した全てのグループの`cpu.shares` は、全て `1024` と同じにする

- 環境構築手順(CentOS6.6)

    ```
    [root@localhost vagrant]# mkdir /cgroup
    [root@localhost vagrant]# mount -t cgroup -o cpu cgroup /cgroup/
    [root@localhost vagrant]# mkdir -p /cgroup/test/{A,B,C}
    [root@localhost vagrant]# head /cgroup/{,test/{,{A,B,C}/}}cpu.shares
    ==> /cgroup/cpu.shares <==
    1024
    
    ==> /cgroup/test/cpu.shares <==
    1024
    
    ==> /cgroup/test/A/cpu.shares <==
    1024
    
    ==> /cgroup/test/B/cpu.shares <==
    1024
    
    ==> /cgroup/test/C/cpu.shares <==
    1024
    ```

- CPU を使用するシェルスクリプト

    ```sh
    #!/bin/bash
    CGROUP=$(mount|grep -w cpu|awk '{print $3}')
    echo $$ > $CGROUP/tasks || exit 1
    while : ; do : ; done
    ```
    ```sh
    loop.sh &            # ルートグループに自身の PID を登録し無限ループ
    loop_test.sh &       # test グループに自身の PID を登録し無限ループ
    loop_test_A.sh &     # test/A グループに自身の PID を登録し無限ループ
    loop_test_B.sh &     # test/B グループに自身の PID を登録し無限ループ
    loop_test_C.sh &     # test/C グループに自身の PID を登録し無限ループ
    ```
    自分自身の PID をスクリプト名にあったグループに登録し、無限ループを行うシェルスクリプト。


検証１
----------------------------------------------------------------------
`A` グループに、無限ループするプロセスを一つ登録した場合の CPU 利用状況。

![](cgroup_test1.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1858 root      20   0  103m 1344 1160 R 99.8  0.3   0:11.30 loop_test_A.sh
```
- `ルート` -> `test` -> `A` と最下層のグループに登録されているが、CPU は 100% 利用できる。


検証２
----------------------------------------------------------------------
`A` `B` `C`の各グループに、無限ループをするプロセスを一つづつ登録した場合の CPU 使用状況。

![](cgroup_test2.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1858 root      20   0  103m 1344 1160 R 33.3  0.3   0:51.82 loop_test_A.sh
 1863 root      20   0  103m 1348 1160 R 33.3  0.3   0:25.00 loop_test_B.sh
 1868 root      20   0  103m 1344 1160 R 33.3  0.3   0:23.39 loop_test_C.sh
```
- 各グループの cpu.shares の値は同じなので、均等に CPU を 1/3 (33.3%)づつ使用している。


検証３
----------------------------------------------------------------------
検証２に加え、`C` グループに、もう一つプロセスを登録した場合の CPU の利用状況。

![](cgroup_test3.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1858 root      20   0  103m 1344 1160 R 33.6  0.3   1:04.14 loop_test_A.sh
 1863 root      20   0  103m 1348 1160 R 33.3  0.3   0:37.32 loop_test_B.sh
 1868 root      20   0  103m 1344 1160 R 16.6  0.3   0:34.81 loop_test_C.sh
 1882 root      20   0  103m 1348 1160 R 16.6  0.3   0:00.88 loop_test_C.sh
```
- グループ A, B に割り当てられている CPU 時間は変わらない
- 検証２でグループ C に割り当てられていた CPU 時間(33.3%)は、２つのプロセス（2570,2573）に分配されている
    

検証４
----------------------------------------------------------------------
検証３に加え、`test`グループに無限ループするスクリプトを一つ、追加登録した場合の CPU 利用状況。

![](cgroup_test4.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1887 root      20   0  103m 1348 1160 R 24.9  0.3   0:05.77 loop_test.sh
 1858 root      20   0  103m 1344 1160 R 24.9  0.3   1:15.43 loop_test_A.sh
 1863 root      20   0  103m 1348 1160 R 24.9  0.3   0:48.61 loop_test_B.sh
 1868 root      20   0  103m 1344 1160 R 12.6  0.3   0:40.46 loop_test_C.sh
 1882 root      20   0  103m 1348 1160 R 12.3  0.3   0:06.53 loop_test_C.sh
```
- CPU 時間は、test グループの１つのプロセス `1887` とグループ`A` `B` `C` で、４等分(25%)されている
- C グループ 配下のプロセスは、４等分された CPU時間(25%) を分配して利用している


検証５
----------------------------------------------------------------------
検証４に加え、さらに`test`グループに無限ループするスクリプトを一つ、追加登録した場合の CPU 利用状況。

![](cgroup_test5.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1892 root      20   0  103m 1348 1160 R 20.3  0.3   0:01.57 loop_test.sh
 1887 root      20   0  103m 1348 1160 R 20.0  0.3   0:14.80 loop_test.sh
 1863 root      20   0  103m 1348 1160 R 20.0  0.3   0:57.63 loop_test_B.sh
 1858 root      20   0  103m 1344 1160 R 20.0  0.3   1:24.45 loop_test_A.sh
 1868 root      20   0  103m 1344 1160 R 10.0  0.3   0:44.97 loop_test_C.sh
 1882 root      20   0  103m 1348 1160 R 10.0  0.3   0:11.05 loop_test_C.sh
```
- CPU 時間は、test グループの２つのプロセス `1892` `1887` とグループ`A` `B` `C` で、５等分(20%)されている
- test グループの２つのプロセス `1892` `1887` は、それぞれ５等分された CPU時間(20%) を利用できる
    

検証６
----------------------------------------------------------------------
検証３に加え、ルートグループに無限ループするスクリプトを一つ、追加登録した場合の CPU 利用状況。

![](cgroup_test6.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1898 root      20   0  103m 1344 1160 R 50.2  0.3   0:03.83 loop.sh
 1858 root      20   0  103m 1344 1160 R 16.6  0.3   1:32.35 loop_test_A.sh
 1863 root      20   0  103m 1348 1160 R 16.6  0.3   1:05.53 loop_test_B.sh
 1868 root      20   0  103m 1344 1160 R  8.3  0.3   0:48.92 loop_test_C.sh
 1882 root      20   0  103m 1348 1160 R  8.3  0.3   0:14.99 loop_test_C.sh
```
- CPU 時間は、ルートグループの１つのプロセス `1898` と `test グループ` で、２等分(50%)されている
- test グループ 配下のプロセスは、２等分された CPU時間(50%) を分配して利用している


検証７
----------------------------------------------------------------------
検証６に加え、さらにルートグループに無限ループするスクリプトを一つ、追加登録した場合の CPU 利用状況。

![](cgroup_test7.png)

```
# 結果
  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 1898 root      20   0  103m 1344 1160 R 33.5  0.3   0:10.72 loop.sh
 1903 root      20   0  103m 1348 1160 R 33.2  0.3   0:01.53 loop.sh
 1858 root      20   0  103m 1344 1160 R 11.3  0.3   1:34.65 loop_test_A.sh
 1863 root      20   0  103m 1348 1160 R 11.0  0.3   1:07.82 loop_test_B.sh
 1882 root      20   0  103m 1348 1160 R  5.6  0.3   0:16.14 loop_test_C.sh
 1868 root      20   0  103m 1344 1160 R  5.3  0.3   0:50.06 loop_test_C.sh
```
- CPU 時間は、ルートグループの２つのプロセス`1898` `1903` と `test グループ` で、３等分(33%)されている
- ルートグループの２つのプロセス `1898` `1903` は、それぞれ３等分された CPU時間(33%) を利用できる
- test グループ 配下のプロセスは、３等分された CPU時間(33%) を分配して利用している


まとめ
----------------------------------------------------------------------
検証７の結果を見れば、cpu.shares の振る舞いがだいたいわかる。

test グループ配下のプロセスが利用できる CPU時間は、ルートグループに属するプロセス数や CPU 利用状況によってかわるので、リソース設計が難しい。

このため、test グループの CPU時間を担保したい場合は、以下のような感じで、一旦ルートグループ配下の全プロセスを別のサブグループ配下に移動してあげればよさそう。

```
mkdir /cgroup/root
cat /cgroup/tasks > /cgrou/root/tasks
```
