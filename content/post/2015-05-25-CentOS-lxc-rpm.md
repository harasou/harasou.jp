---
title: "CentOS 用に LXC の rpm を作成する"
date: 2015-05-25T02:40:46+09:00
tags:
  - lxc
slug: 2015/05/25/CentOS-lxc-rpm
---

Linux でコンテナといえば docker しかさわったことがなかった。LXC は docker よりシンプルで面白そうだったので、勉強用に先づ rpm を作成した。

環境
----------------------------------------------------------------------

- LXC: 1.1.2
- OS:
    - CentOS6.6 (2.6.32-504.16.2.el6.x86_64)
    - CentOS7.1 (3.10.0-229.el7.x86_64)

<!--more-->

LXC の rpm を作成
----------------------------------------------------------------------
本家のサイトに、specfile 付きの tarball が公開されているのでそれをビルドするだけ。

https://linuxcontainers.org/ja/lxc/downloads/

1. rpmbuild 用の環境を準備

    ```
    sudo yum install -y rpmdevtools epel-release
    rpmdev-setuptree
    ```
    - rpmdevtools に含まれる `rpmdev-setuptree`コマンドは、`rpmbuild`実行時に必要なディレクトリを~/rpmbuild 配下に作ってくる。

1. ビルドに必要なパッケージのインストール

    ```
    sudo yum --enablerepo=epel install -y libcap-devel docbook2X graphviz libxslt
    ```

1. LXC の tarball をダウンロード

    ```
    cd ~/rpmbuild/SOURCES/
    wget https://linuxcontainers.org/downloads/lxc//lxc-1.1.2.tar.gz
    ```

1. rpm の作成
    
    ```
    rpmbuild -ta lxc-1.1.2.tar.gz
    ```
    ```
    [vagrant@localhost SOURCES]$ cd ../RPMS/x86_64/ && ll
    合計 904
    -rw-rw-r-- 1 vagrant vagrant 313302  5月 25 02:25 2015 lxc-1.1.2-1.el6.x86_64.rpm
    -rw-rw-r-- 1 vagrant vagrant  12304  5月 25 02:25 2015 lxc-devel-1.1.2-1.el6.x86_64.rpm
    -rw-rw-r-- 1 vagrant vagrant 591964  5月 25 02:25 2015 lxc-libs-1.1.2-1.el6.x86_64.rpm
    ```
    - rpmbuild の -t オプションは specfile ではなく、tarball から作成できる。


LXC のインストール
----------------------------------------------------------------------
rpm コマンドでインストールするだけだが、OS によって依存で必要なパッケージが違っていた。

- CentOS 6

    ```
    sudo yum install -y dnsmasq libcgroup
    rpm -ivh lxc-* lxc-ilbs-*
    ```

- CentOS 7

    ```
    sudo yum install -y bridge-utils libcgroup
    rpm -ivh lxc-* lxc-ilbs-*
    ```
