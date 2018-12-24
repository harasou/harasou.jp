---
title: "mruby-cgroup に memory サブシテムを追加してみた"
date: 2015-05-17T18:38:33+09:00
tags:
  - mruby
  - cgroup
url:  2015/05/17/mruby-cgroup
---

mruby-cgroup は、mruby から cgroup を利用するためのモジュールで、いわゆる libcgroup のバインディング。現在、mruby-cgroup [9cad17343][] で対応しているサブシテムは以下のとおり。

- cpu
- cpu_set
- cpu_acct
- blkio

[9cad17343]: https://github.com/matsumoto-r/mruby-cgroup/blob/9cad17343cf60449c2cc1b7475daefb863086a13/src/mrb_cgroup.c#L45-L50

他に、cgroup のサブシステムには以下のようなものがある(CentOS 6.4)
```
# cat /proc/cgroups
#subsys_name    hierarchy   num_cgroups enabled
cpuset  10  1   1
ns  0   1   1
cpu 11  1   1
cpuacct 12  1   1
memory  13  1   1
devices 14  1   1
freezer 15  1   1
net_cls 16  1   1
blkio   17  1   1
perf_event  0   1   1
net_prio    0   1   1
```

この中から、簡単に使えそうな memory サブシステムを追加してみた。

<!--more-->

libcgroup の構成
----------------------------------------------------------------------
サブシテムを追加するには、libcgroup を知る必要がる。

情報はこちら。
http://libcg.sourceforge.net/html/main.html

libcgroup を利用する場合は以下のような流れ。

1. cgroup の初期化(現在の状態をキャッシュする？) `cgroup_init()`
1. cgroup 管理用の構造体を作成 `cgroup_new_cgroup()`
1. 作成した構造体にサブシステムを登録 `cgroup_add_controller()`
1. サブシステムに対応した制限を設定 `cgroup_add_value_int64()`
1. 構造体を元に cgroup を作成 `cgroup_create_cgroup()`
1. タスクを cgroup に追加 `cgroup_attach_task()`

ソースにするとこんな感じ

```c
#include <libcgroup.h>

int main(void){

  cgroup_init();

  struct cgroup *foo = cgroup_new_cgroup("foo");
  struct cgroup_controller * foo_cpu = cgroup_add_controller(foo, "cpu");
  struct cgroup_controller * foo_mem = cgroup_add_controller(foo, "memory");

  cgroup_add_value_int64(foo_cpu, "cpu.shares", 500);
  cgroup_add_value_int64(foo_mem, "memory.limit_in_bytes", 1048576);

  cgroup_create_cgroup(foo, 0);

  cgroup_attach_task(foo);

  return 0;
}
```

mruby-cgroup の実装
----------------------------------------------------------------------
上記のような libcgroup の流れを mruby-cgroup で以下のように実装している。

1. cgroup の作成

    cgroup の作成については、各サブシテムで同じような処理になるので、以下のようなマクロで実装されていた。
    `cgroup_init`->`cgroup_new_cgroup`->`cgroup_add_controller` の流れは同じ。

    ```c
    #define SET_MRB_CGROUP_INIT_GROUP(gname) \
    static mrb_value mrb_cgroup_##gname##_init(mrb_state *mrb, mrb_value self)                                      \
    {                                                                                                               \
        mrb_cgroup_context *mrb_cg_cxt = (mrb_cgroup_context *)mrb_malloc(mrb, sizeof(mrb_cgroup_context));         \
                                                                                                                    \
        mrb_cg_cxt->type = MRB_CGROUP_##gname;                                                                      \
        if (cgroup_init()) {                                                                                        \
            mrb_raise(mrb, E_RUNTIME_ERROR, "cgoup_init " #gname " failed");                                        \
        }                                                                                                           \
        mrb_get_args(mrb, "o", &mrb_cg_cxt->group_name);                                                            \
        mrb_cg_cxt->cg = cgroup_new_cgroup(RSTRING_PTR(mrb_cg_cxt->group_name));                                    \
        if (mrb_cg_cxt->cg == NULL) {                                                                               \
            mrb_raise(mrb, E_RUNTIME_ERROR, "cgoup_new_cgroup failed");                                             \
        }                                                                                                           \
                                                                                                                    \
        if (cgroup_get_cgroup(mrb_cg_cxt->cg)) {                                                                    \
            mrb_cg_cxt->already_exist = 0;                                                                          \
            mrb_cg_cxt->cgc = cgroup_add_controller(mrb_cg_cxt->cg, #gname);                                        \
            if (mrb_cg_cxt->cgc == NULL) {                                                                          \
                mrb_raise(mrb, E_RUNTIME_ERROR, "cgoup_add_controller " #gname " failed");                          \
            }                                                                                                       \
        } else {                                                                                                    \
            mrb_cg_cxt->already_exist = 1;                                                                          \
            mrb_cg_cxt->cgc = cgroup_get_controller(mrb_cg_cxt->cg, #gname);                                        \
            if (mrb_cg_cxt->cgc == NULL) {                                                                          \
                mrb_cg_cxt->cgc = cgroup_add_controller(mrb_cg_cxt->cg, #gname);                                    \
                if (mrb_cg_cxt->cgc == NULL) {                                                                      \
                    mrb_raise(mrb, E_RUNTIME_ERROR, "get_cgroup success, but add_controller "  #gname " failed");   \
                }                                                                                                   \
            }                                                                                                       \
        }                                                                                                           \
        mrb_iv_set(mrb                                                                                              \
            , self                                                                                                  \
            , mrb_intern_cstr(mrb, "mrb_cgroup_context")                                                                 \
            , mrb_obj_value(Data_Wrap_Struct(mrb                                                                    \
                , mrb->object_class                                                                                 \
                , &mrb_cgroup_context_type                                                                          \
                , (void *)mrb_cg_cxt)                                                                               \
            )                                                                                                       \
        );                                                                                                          \
                                                                                                                    \
        return self;                                                                                                \
    }
    
    SET_MRB_CGROUP_INIT_GROUP(cpu);
    SET_MRB_CGROUP_INIT_GROUP(cpuset);
    SET_MRB_CGROUP_INIT_GROUP(cpuacct);
    SET_MRB_CGROUP_INIT_GROUP(blkio);
    ```
    ref: [mrb_cgroup.c#L240-L291](https://github.com/matsumoto-r/mruby-cgroup/blob/9cad17343cf60449c2cc1b7475daefb863086a13/src/mrb_cgroup.c#L240-L291)

1. サブシステムにパラメータを設定 

    設定には`cgroup_add_value_int64()`ではなく`cgroup_set_value_int64()`が使われていた。同じようにマクロ化されている。

    ```c
    //
    // cgroup_set_value_int64
    //
    #define SET_VALUE_INT64_MRB_CGROUP(gname, key) \
    static mrb_value mrb_cgroup_set_##gname##_##key(mrb_state *mrb, mrb_value self)                      \
    {                                                                                             \
        mrb_cgroup_context *mrb_cg_cxt = mrb_cgroup_get_context(mrb, self, "mrb_cgroup_context"); \
        mrb_int val;                                                                              \
        int code;                                                                                 \
        mrb_get_args(mrb, "i", &val);                                                             \
                                                                                                  \
        if ((code = cgroup_set_value_int64(mrb_cg_cxt->cgc, #gname "." #key, val))) {                      \
            mrb_raisef(mrb, E_RUNTIME_ERROR, "cgroup_set_value_int64 " #gname "." #key " failed: %S", mrb_str_new_cstr(mrb, cgroup_strerror(code))); \
        }                                                                                         \
        mrb_iv_set(mrb                                                                            \
            , self                                                                                \
            , mrb_intern_cstr(mrb, "mrb_cgroup_context")                                               \
            , mrb_obj_value(Data_Wrap_Struct(mrb                                                  \
                , mrb->object_class                                                               \
                , &mrb_cgroup_context_type                                                        \
                , (void *)mrb_cg_cxt)                                                             \
            )                                                                                     \
        );                                                                                        \
                                                                                                  \
        return self;                                                                              \
    }
    
    SET_VALUE_INT64_MRB_CGROUP(cpu, cfs_quota_us);
    SET_VALUE_INT64_MRB_CGROUP(cpu, cfs_period_us);
    SET_VALUE_INT64_MRB_CGROUP(cpu, rt_period_us);
    SET_VALUE_INT64_MRB_CGROUP(cpu, rt_runtime_us);
    SET_VALUE_INT64_MRB_CGROUP(cpu, shares);
    SET_VALUE_INT64_MRB_CGROUP(cpuacct, usage);
    ```
    ref: [mrb_cgroup.c#L293-L325](https://github.com/matsumoto-r/mruby-cgroup/blob/9cad17343cf60449c2cc1b7475daefb863086a13/src/mrb_cgroup.c#L293-L325)

1. cgroup にタスクを登録

    自身を登録する場合(pid が nil)は`cgroup_attach_task()`、pid が指定された場合は`cgroup_attach_task_pid()` が呼ばれる。

    ```c
    static mrb_value mrb_cgroup_attach(mrb_state *mrb, mrb_value self)
    {
        mrb_cgroup_context *mrb_cg_cxt = mrb_cgroup_get_context(mrb, self, "mrb_cgroup_context");
        mrb_value pid = mrb_nil_value();
        mrb_get_args(mrb, "|i", &pid);
    
        if (mrb_nil_p(pid)) {
            cgroup_attach_task(mrb_cg_cxt->cg);
        } else {
            cgroup_attach_task_pid(mrb_cg_cxt->cg, mrb_fixnum(pid));
        }
        mrb_iv_set(mrb
            , self
            , mrb_intern_cstr(mrb, "mrb_cgroup_context")
            , mrb_obj_value(Data_Wrap_Struct(mrb
                , mrb->object_class
                , &mrb_cgroup_context_type
                , (void *)mrb_cg_cxt)
            )
        );
    
        return self;
    }
    ```
    ref: [mrb_cgroup.c#L194-L220](https://github.com/matsumoto-r/mruby-cgroup/blob/9cad17343cf60449c2cc1b7475daefb863086a13/src/mrb_cgroup.c#L194-L220)


memory サブシテムを試す
----------------------------------------------------------------------
mruby-cgroup に memoroy サブシテム(今回はlimit_in_bytesのみ)を追加して動作を確認してみる。mruby-cgroup に以下のような修正を加えて、mruby を build。

作りが良いので、簡単に機能追加できる。@matsumotory さすがです。

```diff
diff --git a/src/mrb_cgroup.c b/src/mrb_cgroup.c
index c63473c..c6dcde6 100644
--- a/src/mrb_cgroup.c
+++ b/src/mrb_cgroup.c
@@ -46,7 +46,8 @@ typedef enum {
     MRB_CGROUP_cpu,
     MRB_CGROUP_cpuset,
     MRB_CGROUP_cpuacct,
-    MRB_CGROUP_blkio
+    MRB_CGROUP_blkio,
+    MRB_CGROUP_memory
 } group_type_t;
 typedef struct cgroup cgroup_t;
 typedef struct cgroup_controller cgroup_controller_t;
@@ -289,6 +290,7 @@ SET_MRB_CGROUP_INIT_GROUP(cpu);
 SET_MRB_CGROUP_INIT_GROUP(cpuset);
 SET_MRB_CGROUP_INIT_GROUP(cpuacct);
 SET_MRB_CGROUP_INIT_GROUP(blkio);
+SET_MRB_CGROUP_INIT_GROUP(memory);

 //
 // cgroup_set_value_int64
@@ -323,6 +325,7 @@ SET_VALUE_INT64_MRB_CGROUP(cpu, rt_period_us);
 SET_VALUE_INT64_MRB_CGROUP(cpu, rt_runtime_us);
 SET_VALUE_INT64_MRB_CGROUP(cpu, shares);
 SET_VALUE_INT64_MRB_CGROUP(cpuacct, usage);
+SET_VALUE_INT64_MRB_CGROUP(memory, limit_in_bytes);

 #define GET_VALUE_INT64_MRB_CGROUP(gname, key) \
 static mrb_value mrb_cgroup_get_##gname##_##key(mrb_state *mrb, mrb_value self)                      \
@@ -351,6 +354,7 @@ GET_VALUE_INT64_MRB_CGROUP(cpu, rt_period_us);
 GET_VALUE_INT64_MRB_CGROUP(cpu, rt_runtime_us);
 GET_VALUE_INT64_MRB_CGROUP(cpu, shares);
 GET_VALUE_INT64_MRB_CGROUP(cpuacct, usage);
+GET_VALUE_INT64_MRB_CGROUP(memory, limit_in_bytes);

 //
 // cgroup_get_value_string
@@ -505,6 +509,7 @@ void mrb_mruby_cgroup_gem_init(mrb_state *mrb)
     struct RClass *cpuacct;
     struct RClass *cpuset;
     struct RClass *blkio;
+    struct RClass *memory;

     cgroup = mrb_define_module(mrb, "Cgroup");
     mrb_define_module_function(mrb, cgroup, "create", mrb_cgroup_create, ARGS_NONE());
@@ -567,6 +572,13 @@ void mrb_mruby_cgroup_gem_init(mrb_state *mrb)
     mrb_define_method(mrb, blkio, "throttle_write_iops_device=", mrb_cgroup_set_blkio_throttle_write_iops_device,
     mrb_define_method(mrb, blkio, "throttle_write_iops_device", mrb_cgroup_get_blkio_throttle_write_iops_device,
     DONE;
+
+    memory = mrb_define_class_under(mrb, cgroup, "MEMORY", mrb->object_class);
+    mrb_include_module(mrb, memory, mrb_module_get(mrb, "Cgroup"));
+    mrb_define_method(mrb, memory, "initialize", mrb_cgroup_memory_init, ARGS_ANY());
+    mrb_define_method(mrb, memory, "limit_in_bytes=", mrb_cgroup_set_memory_limit_in_bytes, ARGS_ANY());
+    mrb_define_method(mrb, memory, "limit_in_bytes", mrb_cgroup_get_memory_limit_in_bytes, ARGS_ANY());
+    DONE;
 }

 void mrb_mruby_cgroup_gem_final(mrb_state *mrb)
```

build した mruby で以下のスクリプト(memory.rb)を実行

```ruby
c = Cgroup::MEMORY.new "/test"
if !c.exist?
  puts "create cgroup memory /test"
  c.create
end

c.limit_in_bytes = 1024 * 8
c.modify

c.attach

# メモリを確保
a=[]
99999.times { a << {} }

if c.exist?
  puts "delete /test group"
  c.delete
end
```
```
# bin/mruby examples/mrbgems/mruby-cgroup/example/memory.rb
Killed
```
見事に kill された。その時の syslog 。oom-killer が走っている。

```
May 17 14:22:02 vagrant-centos64 kernel: mruby invoked oom-killer: gfp_mask=0xd0, order=0, oom_adj=0, oom_score_adj=0
May 17 14:22:02 vagrant-centos64 kernel: mruby cpuset=/ mems_allowed=0
May 17 14:22:02 vagrant-centos64 kernel: Pid: 14095, comm: mruby Not tainted 2.6.32-358.23.2.el6.x86_64 #1
May 17 14:22:02 vagrant-centos64 kernel: Call Trace:
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff810cb641>] ? cpuset_print_task_mems_allowed+0x91/0xb0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8111ce40>] ? dump_header+0x90/0x1b0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8121d4ec>] ? security_real_capable_noaudit+0x3c/0x70
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8111d2c2>] ? oom_kill_process+0x82/0x2a0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8111d201>] ? select_bad_process+0xe1/0x120
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8111da42>] ? mem_cgroup_out_of_memory+0x92/0xb0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81173854>] ? mem_cgroup_handle_oom+0x274/0x2a0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81171290>] ? memcg_oom_wake_function+0x0/0xa0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81173e39>] ? __mem_cgroup_try_charge+0x5b9/0x5d0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff811751b7>] ? mem_cgroup_charge_common+0x87/0xd0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81175248>] ? mem_cgroup_newpage_charge+0x48/0x50
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81143f3c>] ? handle_pte_fault+0x79c/0xb50
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8112c7cf>] ? free_hot_page+0x2f/0x60
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8112f45e>] ? __put_single_page+0x1e/0x30
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8112f5e5>] ? put_page+0x25/0x40
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81154dca>] ? free_page_and_swap_cache+0x2a/0x60
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8114452a>] ? handle_mm_fault+0x23a/0x310
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff810474e9>] ? __do_page_fault+0x139/0x480
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81277681>] ? cpumask_any_but+0x31/0x50
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff811494bf>] ? unmap_region+0xff/0x130
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff8114765e>] ? remove_vma+0x6e/0x90
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81513bfe>] ? do_page_fault+0x3e/0xa0
May 17 14:22:02 vagrant-centos64 kernel: [<ffffffff81510fb5>] ? page_fault+0x25/0x30
May 17 14:22:02 vagrant-centos64 kernel: Task in /test killed as a result of limit of /test
May 17 14:22:02 vagrant-centos64 kernel: memory: usage 8kB, limit 8kB, failcnt 9
May 17 14:22:02 vagrant-centos64 kernel: memory+swap: usage 8kB, limit 9007199254740992kB, failcnt 0
May 17 14:22:02 vagrant-centos64 kernel: Mem-Info:
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA per-cpu:
May 17 14:22:02 vagrant-centos64 kernel: CPU    0: hi:    0, btch:   1 usd:   0
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA32 per-cpu:
May 17 14:22:02 vagrant-centos64 kernel: CPU    0: hi:  186, btch:  31 usd:  54
May 17 14:22:02 vagrant-centos64 kernel: active_anon:4452 inactive_anon:164 isolated_anon:0
May 17 14:22:02 vagrant-centos64 kernel: active_file:48233 inactive_file:40667 isolated_file:0
May 17 14:22:02 vagrant-centos64 kernel: unevictable:0 dirty:0 writeback:0 unstable:0
May 17 14:22:02 vagrant-centos64 kernel: free:38633 slab_reclaimable:9809 slab_unreclaimable:4725
May 17 14:22:02 vagrant-centos64 kernel: mapped:2176 shmem:194 pagetables:724 bounce:0
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA free:15756kB min:760kB low:948kB high:1140kB active_anon:0kB inactive_anon:0kB active_file:0kB inactive_file:0kB unevictable:0kB isolated(anon):0kB isolated(file):0kB present:15368kB mlocked:0kB dirty:0kB writeback:0kB mapped:0kB shmem:0kB slab_reclaimable:0kB slab_unreclaimable:0kB kernel_stack:0kB pagetables:0kB unstable:0kB bounce:0kB writeback_tmp:0kB pages_scanned:0 all_unreclaimable? no
May 17 14:22:02 vagrant-centos64 kernel: lowmem_reserve[]: 0 588 588 588
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA32 free:138776kB min:29912kB low:37388kB high:44868kB active_anon:17808kB inactive_anon:656kB active_file:192932kB inactive_file:162668kB unevictable:0kB isolated(anon):0kB isolated(file):0kB present:602904kB mlocked:0kB dirty:0kB writeback:0kB mapped:8704kB shmem:776kB slab_reclaimable:39236kB slab_unreclaimable:18900kB kernel_stack:704kB pagetables:2896kB unstable:0kB bounce:0kB writeback_tmp:0kB pages_scanned:0 all_unreclaimable? no
May 17 14:22:02 vagrant-centos64 kernel: lowmem_reserve[]: 0 0 0 0
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA: 3*4kB 2*8kB 1*16kB 1*32kB 1*64kB 0*128kB 1*256kB 0*512kB 1*1024kB 1*2048kB 3*4096kB = 15756kB
May 17 14:22:02 vagrant-centos64 kernel: Node 0 DMA32: 2*4kB 4*8kB 349*16kB 283*32kB 289*64kB 99*128kB 63*256kB 12*512kB 5*1024kB 6*2048kB 13*4096kB = 138776kB
May 17 14:22:02 vagrant-centos64 kernel: 89093 total pagecache pages
May 17 14:22:02 vagrant-centos64 kernel: 0 pages in swap cache
May 17 14:22:02 vagrant-centos64 kernel: Swap cache stats: add 0, delete 0, find 0/0
May 17 14:22:02 vagrant-centos64 kernel: Free swap  = 1254392kB
May 17 14:22:02 vagrant-centos64 kernel: Total swap = 1254392kB
May 17 14:22:02 vagrant-centos64 kernel: 156911 pages RAM
May 17 14:22:02 vagrant-centos64 kernel: 6002 pages reserved
May 17 14:22:02 vagrant-centos64 kernel: 75107 pages shared
May 17 14:22:02 vagrant-centos64 kernel: 41918 pages non-shared
May 17 14:22:02 vagrant-centos64 kernel: [ pid ]   uid  tgid total_vm      rss cpu oom_adj oom_score_adj name
May 17 14:22:02 vagrant-centos64 kernel: [14095]     0 14095     3619      677   0       0             0 mruby
May 17 14:22:02 vagrant-centos64 kernel: Memory cgroup out of memory: Kill process 14095 (mruby) score 1000 or sacrifice child
May 17 14:22:02 vagrant-centos64 kernel: Killed process 14095, UID 0, (mruby) total-vm:14476kB, anon-rss:1408kB, file-rss:1300kB
```
