---
title: "第2回ペパボテックカンファレンスで mruby について発表"
date: 2015-07-06T01:44:39+09:00
tags:
  - mruby
url:  2015/07/06/pepabo-tech-conference
---

ブログ書くまでがペパボテックカンファレンス！というプレシャーをうけたので、一昨日(7/4)、福岡天神で開催された「第２回ペパボテックカンファレンス」について記録。

５時間超におよぶカンファレンスに参加してくださったみなさま、本当にお疲れ様でした。

- connpass : http://pepabo.connpass.com/event/16457/
- youtube : https://www.youtube.com/watch?v=SUuaugJ4p7o
- twitter : http://togetter.com/li/842661
- slides : http://kimromi.hatenablog.jp/entry/2015/07/04/211334

@takesi_yosimura さんが、twitter をまとめてくださっていました。ありがとうございます！また、@kimroi さんは発表スライドをまとめてくれていました。ありがとうございます！

<!--more-->

発表内容について
----------------------------------------------------------------------
最近ペパボで積極的に投入している mruby についての事例紹介をしています。

WEBアクセス時に実行される各プロセスのリソース(CPU)を、動的にコントールする方法について。また、それ以外の用途で利用している mruby の事例について。

<div style="width: 65%">
<script async class="speakerdeck-embed" data-slide="1" data-id="8f4290b61a4e47bf85364194023ecdaa" data-ratio="1.33333333333333" src="//speakerdeck.com/assets/embed.js"></script>
</div>


訂正と感謝と感想
----------------------------------------------------------------------

### cgroup 利用時の性能劣化

発表後に、以下のような質問があって回答させていただいたですが、前提の話が足りてなくて正しい回答とは言えなかったので、この場で訂正させていただきます。

質問「リクエストごとに、それぞれのユーザの cgroup にアタッチすると性能が劣化しないか？」

回答「mruby が速いのと、スクリプトもキャッシュするので、それほど劣化はないです」

正しくは、

回答「cgroup へのアタッチは、cgi にのみしか行っていないので、cgi の fork や処理のコストに比べると問題なるような性能劣化はないです」

CGI を対象にしているという前提を説明していませんでした。申し訳ありません...


### vm.swappiness=0 の問題

また、@rrreeeyyy さんより vm.swappiness の情報をいただきました。ありがとうございます。こういった知見はほんとありがたい。

<blockquote class="twitter-tweet" lang="ja"><p lang="ja" dir="ltr">vm.swappiness はカーネルのバージョンによって挙動が違うので 0 に設定したほうがいい時と 10 ぐらいにしておいたほうがいい(0 にするとヤバイ)時がある <a href="https://twitter.com/hashtag/pbtech?src=hash">#pbtech</a></p>&mdash; れい (Yoshikawa Ryota) (@rrreeeyyy) <a href="https://twitter.com/rrreeeyyy/status/617192261781032960">2015, 7月 4</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>
<blockquote class="twitter-tweet" lang="ja"><p lang="ja" dir="ltr">これです / “OOM relation to vm.swappiness=0 in new kernel; kills MySQL server process” <a href="http://t.co/KCH9JRJiRp">http://t.co/KCH9JRJiRp</a></p>&mdash; れい (Yoshikawa Ryota) (@rrreeeyyy) <a href="https://twitter.com/rrreeeyyy/status/617193176932036608">2015, 7月 4</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>


### 懇親会

普段 blog で見てた人と実際にあえたり、上司に振り回されている若者の話を聞けたり、楽しい懇親会でした。

ただ懇親会中、仕事があるのを失念してしまってチームメンバーに迷惑をかけたので、猛烈に反省しています。
