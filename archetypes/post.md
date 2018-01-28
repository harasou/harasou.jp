---
title: "{{ .TranslationBaseName | replaceRE "^[0-9-]{11}(.*)$" "$1" }}"
date: {{ .Date }}
tags:
  - 
slug:           {{ .TranslationBaseName | replaceRE "^([0-9]{4})-([0-9]{2})-([0-9]{2})-(.*)$" "$1/$2/$3/$4" }}
thumbnailImage: {{ .TranslationBaseName | replaceRE "^([0-9]{4})-([0-9]{2})-([0-9]{2})-(.*)$" "$1/$2/$3/$4" }}/
draft: true
---



<!--more-->


-----------------------------------------------------------------------------------


<!--links-->
