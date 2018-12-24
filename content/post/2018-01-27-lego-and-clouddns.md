---
title: lego と Cloud DNS で Let's Encrypt の自動更新
date: 2018-01-27T16:26:25+09:00
tags:
  - GCP
url:            2018/01/27/lego-and-clouddns
thumbnailImage: 2018/01/27/lego-and-clouddns/le-logo-lockonly.png
---

気づいたらブログの証明書の期限が切れていた。めんどくさて数日放置していたけど、
さすがにエンジニアとしてまずいだろうということで自動化することに。

<!--more-->

Let's Encrypt (DNS-01)
-----------------------------------------------------------------------------------

使用していたのは Let's Encrypt の証明書。証明書は ACMEというプロトコルを使用して
発行されるが、その手順の中で「ドメインの所有者どうか」といった認証がある。

この認証によく使われているのは`HTTP-01`だが、今回は`DNS-01`を使っている。

- DNS-01 の流れ
    1. ACMEクラインアントが Let's Encrypt に `challenge` を要求
    1. 受け取った `challenge` を \_acme-challenge.harasou.jp の TXT レコードにセット
    1. Let's Encrypt が TXT レコードの `challenge` を確認できれば証明書発行

自動化にあたって、ACMEクライアントには golang製の [lego][] を利用し、API経由での操作が
必要なDNSプロバイダには Google の DNS サービスである [Cloud DNS][] を使った。

![](lego-dns01.png)


lego のセットアップ
-----------------------------------------------------------------------------------

ACMEクライアントとしては [Certbot][] が有名だが、今回は golang 製の [lego][] を
利用することにする。

```
# Linux-AMD64用のバイナリ
curl -L https://github.com/xenolf/lego/releases/download/v0.4.1/lego_linux_amd64.tar.xz | tar Jxvf - lego_linux_amd64
sudo install -o root -g root -m 755 lego_linux_amd64 /usr/local/bin/lego
```

バイナリ一つ落としてくれば良いので便利。最新の release を落としてきて、パスが通った
ディレクトリに配置しておく。


Cloud DNS 更新の準備
-----------------------------------------------------------------------------------

Cloud DNS を lego から更新するためには [サービスアカウント][SA] の作成が必要 (たぶん)。
対象のプロジェクトで、DNS の操作をサービスアカウントに許可し、lego からの利用時に
必要な key を取得しておく。

```
gcloud iam service-accounts create sa-lego --display-name="lego service account"
gcloud iam service-accounts list
gcloud projects add-iam-policy-binding harasous-garden --member=serviceAccount:sa-lego@harasous-garden.iam.gserviceaccount.com --role=roles/dns.admin
gcloud iam service-accounts keys create key.json --iam-account=sa-lego@harasous-garden.iam.gserviceaccount.com
```

| パラメータ                        | 説明                                        |
|:----------------------------------|:--------------------------------------------|
| sa-lego                           | サービスアカウントの名前。なんでもよい      |
| harasous-garden                   | プロジェクトID。Cloud DNS があるプロジェクト|
| sa-lego@harasous-garden.iam.gserviceaccount.com | サービスアカウントのEMAIL。サービスアカウント名とプロジェクトIDで決まる|
| roles/dns.admin                   | サービスアカウントの[役割][DNSACL]          |
| key.json                          | 保存する key のファイル名                   |

Google の IAM については、全然わかってないので、他にちゃんとしたやり方がありそう
（Cloud KMS とか）。


証明書の取得と更新
-----------------------------------------------------------------------------------

いざ、証明書の取得。Cloud DNS を使う時に必要な変数を設定して、lego コマンドを実行。
うまく行くと `~/.lego/certificates`配下に証明書が作成される。

```
GCE_PROJECT="harasous-garden" \
GCE_DOMAIN="harasou.jp" \
GCE_SERVICE_ACCOUNT_FILE="key.json" \
lego --domains=harasou.jp --email=harasou5+letsencrypt@gmail.com --dns=gcloud run
```

cron に以下のような感じで登録すれば、2ヶ月に一回勝手に更新される。便利。

```
GCE_PROJECT="harasous-garden"
GCE_DOMAIN="harasou.jp"
GCE_SERVICE_ACCOUNT_FILE="key.json"

00 00 01 */2 * /usr/local/bin/lego --domains=harasou.jp --email=harasou5+letsencrypt@gmail.com --dns=gcloud renew && sudo systemctl reload nginx.service
```

<!--links-->
[lego]: https://github.com/xenolf/lego
[Cloud DNS]: https://cloud.google.com/dns/?hl=ja
[Certbot]: https://certbot.eff.org/
[SA]: https://cloud.google.com/iam/docs/service-accounts?hl=ja
[DNSACL]: https://cloud.google.com/dns/access-control?hl=ja
