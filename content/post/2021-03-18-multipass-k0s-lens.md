---
title: "macOS 上で k0s と Lens を使ってみた"
date: 2021-03-18T01:47:41+09:00
tags:
  - k8s
  - macos
slug:           2021/03/18/multipass-k0s-lens
thumbnailImage: 2021/03/18/multipass-k0s-lens/k8s.png
---

CNDO2021 で、ミランティス社の嘉門さんが [Lens のセッション] やってて、面白そうだったので試してみた。
macOS 上に multipass で VM 立てて、k0s で作った Kubernetesクラスタを Lens で操作。

<!--more-->

検証環境
-----------------------------------------------------------------------------------

![](macos-multipass-k0s-lens.png)

```
macOS     ：10.14.6
multipass ：1.6.2
ubuntu    ：20.04 LTS
k0s       ：0.11.0
Lens      ：4.1.4
```

- 「[multipass]」Ubuntu 専用の仮想マシンマネージャ、VM立てるやつ
- 「[k0s]」Kubernetesディストリビューションの一つ、お手軽ワンバイナリ
- 「[Lens]」GUI で K8sクラスタを操作するアプリ

以下、手動でごちゃごちゃやっているけど、Ansible が入ってるなら playbook も公開されてるので、一発で k0s が入る:-P
https://docs.k0sproject.io/latest/examples/ansible-playbook/


k0s によるクラスタ作成
-----------------------------------------------------------------------------------

mac 上のクラスタなら、いくら壊れても構わないので、お気軽に試せる。  
(しかし、やってると、おうちK8sクラスタが欲しくなるなぁ、今更だけど。Raspi か NUC か...)

1. インスタンスの作成（3台）

    multipass を使って、macOS 上に Ubuntu の VM を3つ立てる。node0 がコントロールプレーンで、
    node1・node2 をワーカーノードとする。
    
    ```
    $ echo 0 1 2 | xargs -n1 -IN multipass launch -n nodeN
    Launched: node0
    Launched: node1
    Launched: node2
    $ multipass list
    Name                    State             IPv4             Image
    node0                   Running           192.168.64.10    Ubuntu 20.04 LTS
    node1                   Running           192.168.64.3     Ubuntu 20.04 LTS
    node2                   Running           192.168.64.4     Ubuntu 20.04 LTS
    ```
    複数台に同じコマンド打つことが多いので、`echo 0 1 2 | xargs -n1 -IN `＋「コマンド」みたいな形式を多用
    （コマンド内の文字`N`には echo の数字が入る）。
    あと、`multipass exec` を使って、VM上ではなく、すべて macOS上から操作している。

1. k0s のインストール

    3台のインスタンスそれぞれに、k0s をインストールし、デフォルトの設定ファイルを設置。
    
    ```sh
    $ echo 0 1 2 | xargs -n1 -IN multipass exec nodeN -- bash -c 'curl -sSLf https://get.k0s.sh | sudo sh'
    Downloading k0s from URL: https://github.com/k0sproject/k0s/releases/download/v0.11.0/k0s-v0.11.0-amd64
    Downloading k0s from URL: https://github.com/k0sproject/k0s/releases/download/v0.11.0/k0s-v0.11.0-amd64
    Downloading k0s from URL: https://github.com/k0sproject/k0s/releases/download/v0.11.0/k0s-v0.11.0-amd64
    $
    $ echo 0 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo mkdir /etc/k0s
    $ echo 0 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo sh -c 'k0s default-config > /etc/k0s/k0s.yaml'
    ```

1. コントロールプレーン（node0）の k0s を起動

    install サブコマンドで、k0s の unitファイル（systemd）を作成し、起動。
    
    ```
    $ multipass exec node0 -- sudo k0s install controller -c /etc/k0s/k0s.yaml
    INFO[2021-03-15 01:21:07] creating user: etcd
    INFO[2021-03-15 01:21:07] creating user: kube-apiserver
    INFO[2021-03-15 01:21:07] creating user: konnectivity-server
    INFO[2021-03-15 01:21:07] creating user: kube-scheduler
    INFO[2021-03-15 01:21:07] Installing k0s service
    $
    $ multipass exec node0 -- sudo systemctl start k0scontroller
    $ multipass exec node0 -- sudo k0s status
    Version: v0.11.0
    Process ID: 2642
    Parent Process ID: 1
    Role: controller
    Init System: linux-systemd
    ```

1. token の作成

    ワーカーノード上の kubelet が使用する token を生成。
    この token は、各ワーカーノードで必要なので、k0s の設定ファイルと同様に、/etc/k0s/ 配下に設置しておく。
    
    ```
    $ multipass exec node0 -- sudo k0s token create --role=worker > token-worker
    $
    $ echo 1 2 | xargs -n1 -IN multipass transfer token-worker nodeN:token-worker
    $ echo 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo mv token-worker /etc/k0s/
    ```
    ちなみにこの token は、base64 + gzip になっているので、こんな感じでデコード可能。
    ```
    $ cat token-worker | base64 -D | gzip -d -
    
    apiVersion: v1
    clusters:
    - cluster:
        server: https://192.168.64.10:6443
        certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURBRENDQWVpZ0F3SUJBZ0lVUVBadXVoc2h6Tzh5Vlk2VE1YcmR3ZjFZZkRVd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF4TU5hM1ZpWlhKdVpYUmxjeTFqWVRBZUZ3MHlNVEF6TVRReE5qRTJNREJhRncwegpNVEF6TVRJeE5qRTJNREJhTUJneEZqQVVCZ05WQkFNVERXdDFZbVZ5Ym1WMFpYTXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUN2UUxDMXNzdnY2bVVwdXhLTEtjekEzOG9YOWZtZ0RsOEEKeU01dUpyTmpZdVJqTXFvaFJIQ3FPay83aHhuLzRaTmdrQ2U1Y1JQRXhyS2JCZkJEOXlhNXZqak1wU2VUSWd6Nwo2SlBBbnBwQityUTh6Z2pRaVBSeFRDcnI1MWZidjhkSjZjZmYrNWl1Q3E2eWI2VFNWdzZ0UkM2eGNvQ01aNGRIClZJRHpCdlY3OXhQV2VTeis1VkxpODNoalI0eGFGUkdTRDZsRXJoQng0Rmxnc2pFUVZkYVF6RktlN2RCZDJGeEgKZG1SVlg5SndESkZmaTVyT3pka3NYUnFJVGlrWWV4SEEzNUVFN05YV2Zsa0x4SWtOZ0hWMkpyeFRkaGRLVzBwMgpVUzJnZzBBWTR1UmQxNGRZeTQvS3dpdUVvTlNBQi9BaEVqUysrTE9RbHp0bzMvVllDMkFUQWdNQkFBR2pRakJBCk1BNEdBMVVkRHdFQi93UUVBd0lCQmpBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJRd1Q4enUKMWxMZUMzRUJtSnVVRDk3N2JORkFMekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBcnFXbDNNY2J5YzFtYU5maQp0T0h6ZzZSbEVHVnEzdDFQNnN4TUsyaTByNXBmc2FjanFxZllqdFpXVkc1Mkw1SHJUNlJIbFVCWnhocU1GZzNBCkRaUXhYVUlWRzB0dWwvV0phVlAwVCtxcUFaS1FHcVZveWU2WUZ4ckRpRnhQK3k2SlI3cTVSbjJrQ2tldERJTHkKWFE2YWZXekI3Q2xMekxlNTliZkpQeURRNElHYWYwSzRyWW44b1ZoVWFaRnVPQXI5VWZ5eitzRnlYWUl1SEY4KwpVd0tWWGE3VUtoM05aRjBjNGV5bnNJc1o2bVdMNmlscVNHOUpGSTIxMTFKeThNRENWOFdxYzRINGhYaXF4WnY5CnBCWUpDSmNuR1F6RkVsamtwM1JSRjRKL3VkRDMxenl0aXBrSjdyUGNFWlBTU3Iwd3pzMmljZVRkN3NWelZYTVAKb29jV0ZnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
      name: k0s
    contexts:
    - context:
        cluster: k0s
        user: kubelet-bootstrap
      name: k0s
    current-context: k0s
    kind: Config
    preferences: {}
    users:
    - name: kubelet-bootstrap
      user:
        token: 1ew87q.nbbjnm39bqqzp1cw
    ```

1. ワーカーノード（node1・node2）の k0s を起動

    前述の手順で作成した k0s.yaml と token-woker を指定して、k0s の unit ファイル（systemd）を作成し、起動。
    k0s のバイナリは同じなので、起動時のオプションによって controll plane か worker node か変わる。便利。
    
    ```
    $ echo 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo k0s install worker -c /etc/k0s/k0s.yaml --token-file /etc/k0s/token-worker
    time="2021-03-15 01:25:38" level=info msg="Installing k0s service"
    time="2021-03-15 01:25:39" level=info msg="Installing k0s service"
    $ 
    $ echo 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo systemctl start k0sworker
    $ echo 1 2 | xargs -n1 -IN multipass exec nodeN -- sudo k0s status
    Version: v0.11.0
    Process ID: 3357
    Parent Process ID: 1
    Role: worker
    Init System: linux-systemd
    Version: v0.11.0
    Process ID: 3264
    Parent Process ID: 1
    Role: worker
    Init System: linux-systemd
    ```

Lens によるクラスタの操作
-----------------------------------------------------------------------------------

### 準備

1. Lens のインストール
    - github の [releases] からダウンロード
1. kubeconfig の作成
    - macOS 上に kubeconfig を作成する
    ```
    $ multipass list | grep node0
    node0                   Running           192.168.64.10    Ubuntu 20.04 LTS
    $
    $ ## localhost を node0 の IP に変更して作成
    $ multipass exec node0 -- sudo cat /var/lib/k0s/pki/admin.conf | sed 's/localhost/192.168.64.10/' > k0s.conf
    $ ls $PWD/k0s.conf
    /Users/harasou/k0s/k0s.conf
    ```

### k0s のクラスタを Lens に登録

上記の /Users/harasou/k0s/k0s.conf を指定して、クラスタを追加。

![](lens-01.png)
![](lens-02.png)

### Lens 上の Terminal から ReplicaSet をデプロイ

ウィンドウ下の方にある「Terminal」をクリックして、ターミナルを起動。
ここで実行される kubectl は、クラスタのバージョンに合ったものになるらしい。

> kubectl create deployment nginx --image=gcr.io/google-containers/nginx --replicas=5

![](lens-03.png)

### Node の縮退

Cordon / Uncordon、Drain / Undrain などが、各ノードのメニューから 1クリックでできる。

Cordon

![](lens-05.png)
![](lens-06.png)

Drain

![](lens-07.png)
![](lens-08.png)
![](lens-09.png)

ちゃんと、移動されてる。

![](lens-10.png)

### Pod への attach

各Pod のメニューから「Shell」を選択。新しいタブが開いて、コンソールが表示される。

![](lens-11.png)
![](lens-12.png)

### Node への attach

各ノードのメニューから「Shell」を選択。新しいタブが開いて、コンソールが表示される。

![](lens-13.png)
![](lens-14.png)

### Prometheus のインストール

Lens の設定画面から、1クリックするだけで Prometheus がインストールされ、CPUやメモリの情報が見れるようになる。

初期状態だと何も表示されていない。

![](lens-16.png)

ウィンドウ右上の歯車マークから設定を開くと、画面下部に Prometheus のインストールボタンがある。

![](lens-17.png)

クリックして、インストールすると、「lens-metrics」ネームスペースが作成され、prometheus や node-exporter などの pod が起動する。

![](lens-19.png)
![](lens-20.png)

リソース状況が表示された。めちゃくちゃ簡単。

![](lens-21.png)

後片づけ
-----------------------------------------------------------------------------------

起動した VM を削除。

```
$ multipass list
Name                    State             IPv4             Image
node0                   Running           192.168.64.10    Ubuntu 20.04 LTS
node1                   Running           192.168.64.3     Ubuntu 20.04 LTS
                                          10.244.166.128
node2                   Running           192.168.64.4     Ubuntu 20.04 LTS
                                          10.244.104.0
$ multipass delete --all
$ multipass list
Name                    State             IPv4             Image
node0                   Deleted           --               Not Available
node1                   Deleted           --               Not Available
node2                   Deleted           --               Not Available
$ multipass purge
$
$ multipass list
No instances found.
```

プロダクション環境を GUI で操作するのはちょっと怖いけど、ちゃんと与えられた権限でしか動かないし、
k8s を勉強するには、全体の関連や操作が理解しやすいので、かなり便利と感じた。

<!--links-->

[k0s]: https://docs.k0sproject.io/
[lens]: https://k8slens.dev/
[multipass]: https://multipass.run/
[Mirantis 社]: https://www.mirantis.com/
[releases]: https://github.com/lensapp/lens/releases/latest
[Lens のセッション]: https://event.cloudnativedays.jp/cndo2021/talks/211
