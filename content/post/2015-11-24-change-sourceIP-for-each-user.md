---
title: "外部へ通信時のソースIP をユーザごとに変更する"
date: 2015-11-24T02:52:38+09:00
tags:
    - iptables
slug:           2015/11/24/change-sourceip-for-each-user
thumbnailImage: 2015/11/24/change-sourceip-for-each-user/processes.png
---

「ユーザ単位で、通信時に使用するソースIP を指定できないか？」って話があって、cgroup や fwmark とか使えばできるんじゃない？って思ってたけど、iptables だけであっさりできたって話。

<!--more-->

こんな感じで、サーバ上のプロセスが外部へ通信を行う際に、ユーザごとに別々のソースIP になってほしいって要件。

![](processes.png)

上の例ではプライベートIP を使用しているが、利用時の想定はグローバルIP (IPマスカレードされたら意味なし :-P)。


環境
----------------------------------------------------------------------
いつものごとく vagrant で。

- CentOS 7.1 (3.10.0-229.el7.x86_64)


手順
----------------------------------------------------------------------
いろいろ面倒くさそうな手順を考えていたが、よく考えると iptables だけであっさり対応できる。上記画像のような環境を構築する手順。

1. ユーザを追加

    ```sh
    # useradd userA
    # useradd userB
    # useradd userC
    #
    # tail -3 /etc/passwd
    userA:x:1001:1001::/home/userA:/bin/bash
    userB:x:1002:1002::/home/userB:/bin/bash
    userC:x:1003:1003::/home/userC:/bin/bash
    ```

1. IP の追加
    指定するソースIP をサーバに追加。

    ```sh
    # ip addr add 10.0.2.101/24 dev enp0s3
    # ip addr add 10.0.2.102/24 dev enp0s3
    # ip addr add 10.0.2.103/24 dev enp0s3
    # 
    # ip a s enp0s3
    2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
        link/ether 08:00:27:ea:9b:b5 brd ff:ff:ff:ff:ff:ff
        inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic enp0s3
           valid_lft 84388sec preferred_lft 84388sec
        inet 10.0.2.101/24 scope global secondary enp0s3
           valid_lft forever preferred_lft forever
        inet 10.0.2.102/24 scope global secondary enp0s3
           valid_lft forever preferred_lft forever
        inet 10.0.2.103/24 scope global secondary enp0s3
           valid_lft forever preferred_lft forever
        inet6 fe80::a00:27ff:feea:9bb5/64 scope link
           valid_lft forever preferred_lft forever
    ```

1. SNAT の追加
    owner モジュールを使用して、ユーザごとに SNAT (ソースIPの書き換え)を行う

    ```sh
    # iptables -t nat -A POSTROUTING -m owner --uid-owner userA -j SNAT --to-source 10.0.2.101
    # iptables -t nat -A POSTROUTING -m owner --uid-owner userB -j SNAT --to-source 10.0.2.102
    # iptables -t nat -A POSTROUTING -m owner --uid-owner userC -j SNAT --to-source 10.0.2.103
    #
    # iptables -t nat -nvL
    Chain PREROUTING (policy ACCEPT 2 packets, 620 bytes)
     pkts bytes target     prot opt in     out     source               destination
    
    Chain INPUT (policy ACCEPT 1 packets, 44 bytes)
     pkts bytes target     prot opt in     out     source               destination
    
    Chain OUTPUT (policy ACCEPT 24 packets, 1805 bytes)
     pkts bytes target     prot opt in     out     source               destination
    
    Chain POSTROUTING (policy ACCEPT 17 packets, 1262 bytes)
     pkts bytes target     prot opt in     out     source               destination
        0     0 SNAT       all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1001 to:10.0.2.101
        0     0 SNAT       all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1002 to:10.0.2.102
        0     0 SNAT       all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1003 to:10.0.2.103
    ```


検証
----------------------------------------------------------------------

`userB` で ping を打った際の tcpdump

```sh
# sudo -u userB ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=63 time=27.4 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=63 time=30.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=63 time=26.4 ms
 :
```
```sh
# tcpdump -n icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on enp0s3, link-type EN10MB (Ethernet), capture size 65535 bytes
08:09:53.760118 IP 10.0.2.102 > 8.8.8.8: ICMP echo request, id 20790, seq 1, length 64
08:09:53.790121 IP 8.8.8.8 > 10.0.2.102: ICMP echo reply, id 20790, seq 1, length 64
08:09:54.763025 IP 10.0.2.102 > 8.8.8.8: ICMP echo request, id 20790, seq 2, length 64
08:09:54.797682 IP 8.8.8.8 > 10.0.2.102: ICMP echo reply, id 20790, seq 2, length 64
08:09:55.766156 IP 10.0.2.102 > 8.8.8.8: ICMP echo request, id 20790, seq 3, length 64
 :
```

ちゃんと userB のソースIP は `10.0.2.102` になっている。
