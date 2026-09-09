#!/usr/bin/env python3
"""Summarize completed measurement receipts without manufacturing missing data."""
import json
from pathlib import Path
from statistics import mean
ROOT=Path(__file__).resolve().parents[1]
reports={name:json.loads((ROOT/f'artifacts/performance-{name}.json').read_text()) for name in ['editor-run','packaged']}
build=json.loads((ROOT/'artifacts/build-receipt.json').read_text())
for report in reports.values():
    if report['failures'] or report['source_sha256']!=build['source_sha256'] or report['viewport_size']!=[1920,1080]:
        raise RuntimeError('Incomplete, mismatched or invalid performance receipt')
lines=['# 性能与稳定性实测','',
'硬件为 Apple M4、16 GiB 统一内存；实际渲染图像 1920×1080，Godot 4.7.2 / Metal Mobile。以下数据来自完整的运行记录，不从截图速度或无窗口执行推算。','',
'编辑器模式是编辑器引擎运行游戏，同时保留一个最小化的编辑器窗口；包装模式使用独立 release 应用。测试脚本检查编辑器进程全程存活。帧间隔取实际 `frame_post_draw` 回调，测量区间不强制绘制；它是引擎渲染计时，不是外部显示器捕获。每场景预热，切换操作的间隔不纳入稳态帧率。','',
'30 FPS 判据为：99% 帧间隔 ≤33.334 ms，且每个完整一秒窗口至少 30 帧。单独记录最长帧，避免平均值掩盖抖动。','',
'| 模式 / 场景 | 平均 FPS | P99 / ms | 最长帧 / ms | 最低完整秒 FPS | 30 FPS 判据 |','|---|---:|---:|---:|---:|---|']
for mode,r in reports.items():
    for scene,s in r['frames'].items():
        lines.append(f"| {mode} / {scene} | {s['mean_fps']:.2f} | {s['p99_ms']:.2f} | {s['max_ms']:.2f} | {s['minimum_complete_second_fps']} | {'通过' if s['meets_30fps_p99'] else '未通过'} |")
lines+=['','## 内存、响应与重复操作','']
for mode,r in reports.items():
    rss=[s['runtime_rss_mib'] for s in r['rss_samples'] if s.get('runtime_rss_mib',0)>0]
    response=r['request_to_commit'];compute=r['solver_compute']
    lines.append(f"- {mode}：总运行 {r['wall_seconds']:.1f} 秒，进程 RSS 峰值 {max(rss):.1f} MiB；求解器计算平均 {compute['mean_ms']:.2f} ms、P99 {compute['p99_ms']:.2f} ms；请求等待至主线程提交平均 {response['mean_ms']:.2f} ms、P99 {response['p99_ms']:.2f} ms。响应样本包括配液、分样、保存状态回放等，不能当作每种操作各自的统计。")
    editor=[s['editor_ui_rss_mib'] for s in r['rss_samples'] if s.get('editor_ui_rss_mib',0)>0]
    if editor:lines.append(f"- 编辑器窗口自身的 RSS 峰值 {max(editor):.1f} MiB，游戏进程内存另计。")
r=reports['packaged'];cycles=[s for s in r['observations'] if s['label'].startswith('cycle_')]
if len(cycles)<12:raise RuntimeError('Not enough repeated lifecycle evidence')
first=cycles[:6];last=cycles[-6:]
def rss_at(t):
    return min((s for s in r['rss_samples'] if s.get('runtime_rss_mib',0)>0),key=lambda s:abs(s['wall_s']-t))['runtime_rss_mib']
a=mean(rss_at(s['wall_s']) for s in first);b=mean(rss_at(s['wall_s']) for s in last)
static_a=mean(s['static_bytes'] for s in first)/1024**2;static_b=mean(s['static_bytes'] for s in last)/1024**2
lines += ['',f"打包程序完成 {len(cycles)} 轮重复生命周期操作（约 {cycles[-1]['wall_s']-cycles[0]['wall_s']:.0f} 秒）：重置 → 稀酸碱等量加入 → pH 与体积核对 → 保存/加载 → 轮换六个物理实验台模型。每次还原检查守恒状态，运行日志无脚本错误或泄漏警告。",'',
f"比较开头与末尾各六轮（覆盖同一组模型），平均 RSS {a:.1f} → {b:.1f} MiB，变化 {b-a:+.1f} MiB；Godot 静态内存 {static_a:.1f} → {static_b:.1f} MiB。各轮孤立节点监测范围 {min(s['orphan_nodes'] for s in cycles):.0f}–{max(s['orphan_nodes'] for s in cycles):.0f}。RSS 由系统每秒采样，包含分配器缓存；该有限时段不能证明任意长时间或任意操作序列均无泄漏。",'',
'CSV 保存/恢复、错误保留、原料元素与氢氧守恒、加热能量账另见完整回归 `artifacts/verification.json`。无窗口发布应用检查见 `artifacts/packaged-smoke.json`，不计入帧率。','',
f"源文件指纹：`{build['source_sha256']}`。构建文件哈希见 `artifacts/build-receipt.json`；原始实测为 `artifacts/performance-editor-run.json` 和 `artifacts/performance-packaged.json`。"]
(ROOT/'docs/PERFORMANCE.md').write_text('\n'.join(lines)+'\n')
summary={'all_scene_fps_pass':all(s['meets_30fps_p99'] for r in reports.values() for s in r['frames'].values()),'cycles':len(cycles),'rss_first_six_mib':a,'rss_last_six_mib':b,'rss_change_mib':b-a,'static_change_mib':static_b-static_a,'source_sha256':build['source_sha256']}
(ROOT/'artifacts/performance-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
