---
title: "Alfred をバージョンアップすると iTerm2 でのコマンド実行ができなくなった"
date: 2015-09-09T23:58:11+09:00
tags:
  - alfred
slug:           2015/09/09/alfred-iterm2
thumbnailImage: 2015/09/09/alfred-iterm2/alfred.png
---

Alfred から実行するターミナルコマンドは、iTerm2 を使用していたが、Alfred のバージョンアップをすると iTerm2 が起動しなくなっていた。

<!--more-->

![](alfred-0.png)

調べてみると、Alfred 2.7.2 から Terminal コマンドを iTerm2 上で実行したい場合は、"Custom" スクリプトの作成が必要なとのこと。https://www.alfredapp.com/blog/tips-and-tricks/better-iterm-integration-in-alfred/

> With the upcoming release of Alfred 2.7.2, the default iTerm integration has been replaced by the "Custom" scripts option. This allows for a more up-to-date and more flexible way to handle the iTerm integration, using scripts created by one of our fantastic users, Stuart Ryan.


カスタムスクリプトの作成
======================================================================

iTerm2 を Alfred から利用したい人のために、スクリプトを公開されている人もいる。

- [Custom Terminal Applescripts for Alfred to Fix iTerm Behaviour](http://technicalnotebook.com/alfred-workflows/custom-terminal-applescripts-for-alfred-to-fix-iterm-behaviour/)
    - [iTerm v2.1 用 script](https://github.com/stuartcryan/custom-iterm-applescripts-for-alfred/blob/master/custom_iterm_script_iterm_2.1.1.applescript)

公開されているスクリプトだと思った感じに動かなかったので、こんな感じのスクリプトを書いた。動きとして、常に新しいタブを開いて、入力されたコマンドを実行する。

```
on alfred_script(q)
    tell application "iTerm"
        
        -- iTerm が起動していない場合
        if not running then
            launch session "Default"
            
        -- iTerm は起動しているが、ウィンドウがない場合
        else if (count terminals) is 0 then
            tell (make new terminal)
                launch session "Default"
            end tell
            
        -- iTerm は起動しており、ウィンドウも普通に開いている場合
        else
            tell current terminal
                launch session "Default"
            end tell
        end if
        
        -- 入力されたコマンドを実行
        tell current session of current terminal
            write text q
        end tell
        
    end tell
end alfred_script
```

上記スクリプトを Alfred の [Features] -> [Terminal / Shell] -> [Application:] で `Custom` を選択し、登録する。

![](alfred-1.png)

無事、iTerm2 復活。
