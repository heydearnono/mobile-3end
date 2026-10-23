#!/usr/bin/env bash
# 填空检查：./check.sh M1（里程碑）/ ./check.sh S1（Swift 语言专项，只跑单测）
# 1. 列出还没填的空（代码里剩下的 TODO("M1-n")）
# 2. 在 iPhone 模拟器上跑单测 + UI 测试（S 系列只跑单测），按空汇总结果
#
# 实现说明：TODO() 用 fatalError，单测是 hosted 的（跑在 App 进程里），撞到空会让整个测试进程崩掉。
# xcodebuild 会自动重启测试进程继续跑后面的测试（日志里的 "Restarting after unexpected exit"），
# 崩在哪个空：单测从 xcodebuild 输出里的 Fatal error 读，UI 测试从 App 崩溃前写的 $todo_log 读
set -uo pipefail

M="${1:-}"
if [[ ! "$M" =~ ^[MS][0-9]+$ ]]; then
  echo "用法：./check.sh M1 或 ./check.sh S1" >&2
  exit 2
fi
m="$(echo "$M" | tr 'MS' 'ms')"
cd "$(dirname "$0")"

log=/tmp/m3e-ios-check.log
todo_log=/tmp/m3e-ios-todo.log
result=build/check.xcresult
derived=build/DerivedData

echo "== 未填的空"
# 跳过被注释掉的 TODO（把原空注释保留下来对照也算已填）
left="$(grep -rnE "TODO\(\"$M-[0-9]+\"\)" Mobile3End | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' | sed -E 's#^([^:]+:[0-9]+:).*(TODO\("[^"]+"\)).*#\1\2#' | sed -E 's#^Mobile3End/##; s#TODO\("(.*)"\)#\1#')"
if [[ -z "$left" ]]; then
  echo "（无）"
else
  echo "$left" | awk -F: '{ printf "  %-8s %s:%s\n", $3, $1, $2 }' | sort -t- -k2 -n
fi

# S 系列：覆盖的空全都还没填的测试不跑，直接报「还没填」。
# 每撞到一个空测试进程就崩一次，模拟器重启测试进程要 20 多秒，16 个空全撞一遍要 7 分钟多
skip_file=/tmp/m3e-ios-skip.txt
: >"$skip_file"
if [[ "$M" == S* && -f "Mobile3EndTests/${M}Tests.swift" ]]; then
  left_ids="$(echo "$left" | awk -F: 'NF >= 3 { print $3 }' | sort -u)"
  grep -oE "func test_${m}_[A-Za-z0-9_]+" "Mobile3EndTests/${M}Tests.swift" | sed 's/^func //' | while read -r t; do
    nums="$(echo "$t" | grep -oE "${m}_[0-9]+" | sed -E "s/^${m}_//" | grep -vx 0 | sort -u)"
    [[ -z "$nums" ]] && continue
    all_left=1
    for n in $nums; do
      echo "$left_ids" | grep -qx "$M-$n" || all_left=0
    done
    [[ $all_left == 1 ]] && echo "$t" >>"$skip_file"
  done
fi

echo
echo "== 运行测试（首次较慢）"

# S 系列虽然是纯逻辑单测，也要模拟器：单测 target 是 hosted 的（跑在 iOS App 进程里），iOS 的测试只能在模拟器 / 真机上跑。
# 区别只是 S 系列先编译、有要跑的测试时才启动模拟器
# 挑一个可用的 iPhone 模拟器：已启动的优先，其次 iPhone 17，再其次系统版本最新的
udid="$(xcrun simctl list devices available -j | python3 -I -c '
import json, re, sys
devs = []
for runtime, items in json.load(sys.stdin)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    for d in items:
        if d["name"].startswith("iPhone"):
            devs.append((d["state"] == "Booted", d["name"] == "iPhone 17", (int(m[1]), int(m[2])), d["udid"], d["name"]))
devs.sort(reverse=True)
print(f"{devs[0][3]}\t{devs[0][4]}" if devs else "")
')"
if [[ -z "$udid" ]]; then
  echo "没有可用的 iPhone 模拟器。Xcode → Settings → Components 里装一个 iOS 运行时后重试"
  exit 1
fi
sim_name="${udid#*$'\t'}"
udid="${udid%%$'\t'*}"
boot_sim() {
  if ! xcrun simctl list devices | grep -q "$udid) (Booted)"; then
    echo "启动模拟器 $sim_name …"
    xcrun simctl boot "$udid" >/dev/null 2>&1
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
  fi
  echo "模拟器：$sim_name"
}
[[ "$M" == M* ]] && boot_sim

# M2 有一个连真实 mock 服务的测试，没开服务就临时开一个
server_pid=""
if [[ "$M" == "M2" ]] && ! curl -s -o /dev/null --max-time 1 http://localhost:8000/api/files.json; then
  python3 -m http.server 8000 -d ../mock >/dev/null 2>&1 &
  server_pid=$!
  trap '[[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null' EXIT
  sleep 1
fi

dest="id=$udid"
xcodebuild -project Mobile3End.xcodeproj -scheme Mobile3End -destination "$dest" -derivedDataPath "$derived" \
  build-for-testing >"$log" 2>&1
if ! grep -q 'TEST BUILD SUCCEEDED' "$log"; then
  echo "编译失败："
  grep -E ': error: ' "$log" | sed -E "s#^$PWD/##" | sort -u
  exit 1
fi

only=()
if [[ "$M" == S* ]]; then
  [[ -f "Mobile3EndTests/${M}Tests.swift" ]] && only+=("-only-testing:Mobile3EndTests/${M}Tests")
  while read -r t; do
    [[ -n "$t" ]] && only+=("-skip-testing:Mobile3EndTests/${M}Tests/$t")
  done <"$skip_file"
else
  [[ -f "Mobile3EndTests/${M}LogicTests.swift" ]] && only+=("-only-testing:Mobile3EndTests/${M}LogicTests")
  [[ -f "Mobile3EndUITests/${M}UiTests.swift" ]] && only+=("-only-testing:Mobile3EndUITests/${M}UiTests")
fi
if [[ ${#only[@]} -eq 0 ]]; then
  echo "$M 没有测试"
  exit 0
fi

run_tests() {
  rm -rf "$result" "$todo_log"
  TEST_RUNNER_M3E_TODO_LOG="$todo_log" xcodebuild -project Mobile3End.xcodeproj -scheme Mobile3End -destination "$dest" \
    -derivedDataPath "$derived" -resultBundlePath "$result" -parallel-testing-enabled NO \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 \
    test-without-building "${only[@]}" >>"$log" 2>&1
}
[[ "$M" == S* ]] && boot_sim
run_tests
# 模拟器偶尔拒绝启动 App（"failed preflight checks" / Busy），重跑一次
if grep -qE 'failed preflight checks|Simulator device failed to launch' "$log"; then
  echo "模拟器启动 App 失败，重试一次 …"
  run_tests
fi

echo
echo "== 结果"
python3 -I - "$m" "$result" "$log" "$todo_log" "$skip_file" <<'PY'
import json, os, re, subprocess, sys

m, result, log_path, todo_path, skip_path = sys.argv[1:6]
skipped = [l.strip() for l in open(skip_path, encoding="utf-8") if l.strip()] if os.path.exists(skip_path) else []
if not os.path.exists(result):
    print(f"没有找到测试结果，完整日志见 {log_path}")
    sys.exit(1)

tree = json.loads(subprocess.run(
    ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", result, "--compact"],
    capture_output=True, text=True).stdout or "{}")

# 单测崩溃：xcodebuild 输出里 "Test Case '-[X.Class test]' started." 之后出现的 Fatal error 属于这个测试
crash_todo = {}
current = None
for line in open(log_path, encoding="utf-8", errors="replace"):
    s = re.search(r"Test Case '-\[\S+?\.(\S+) (\S+)\]' started", line)
    if s:
        current = f"{s[1]}/{s[2]}"
        continue
    t = re.search(r"An operation is not implemented: ([MS]\d+-\d+)", line)
    if t and current:
        crash_todo.setdefault(current, t[1])
# UI 测试崩溃：App 崩之前写的「-[Class test]\tM1-3」
if os.path.exists(todo_path):
    for line in open(todo_path, encoding="utf-8"):
        u = re.match(r"-\[(\S+) (\S+)\]\t([MS]\d+-\d+)", line)
        if u:
            crash_todo.setdefault(f"{u[1]}/{u[2]}", u[3])

def cases(node, suite=""):
    if node.get("nodeType") == "Test Case":
        yield suite, node
    for c in node.get("children", []):
        yield from cases(c, node["name"] if node.get("nodeType") == "Test Suite" else suite)

failed = 0
rows = []
for root in tree.get("testNodes", []):
    for suite, c in cases(root):
        name = re.sub(r"^test_|\(\)$", "", c["name"])
        if not name.startswith(m + "_"):
            continue
        blanks = sorted({f"{m.upper()}-{n}" for n in re.findall(m + r"_(\d+)", name) if n != "0"},
                        key=lambda b: int(b.split("-")[1]))
        if blanks:
            label = ", ".join(blanks)
        elif "_task_" in name:
            label = "手工任务"
        else:
            label = "综合" if "e2e" in name else "示例"
        order = int(blanks[0].split("-")[1]) if blanks else (99 if "e2e" in name else (98 if "_task_" in name else 0))
        status = c.get("result")
        messages = [x["name"] for x in c.get("children", []) if x.get("nodeType") == "Failure Message"]
        if status == "Passed":
            rows.append((order, name, f"  ✅ {label}  {name}"))
            continue
        if status == "Skipped":
            why = next((x["name"] for x in c.get("children", []) if x.get("nodeType") != "Failure Message"), "")
            rows.append((order, name, f"  ⏭  {label}  {name}\n       跳过：{why[:160]}"))
            continue
        failed += 1
        todo = crash_todo.get(f"{suite}/{c['name'].removesuffix('()')}")
        if not todo:
            t = re.search(r"An operation is not implemented: ([MS]\d+-\d+)", " ".join(messages))
            todo = t[1] if t else None
        if todo:
            why = f"运行到了未填的 {todo}"
        else:
            # App 崩溃之后的断言失败是连带的，只显示第一条
            first = next((x for x in messages if x.strip()), "失败（没有失败信息，见完整日志）")
            if "crashed" in first or first.startswith("Crash:"):
                first = "崩溃：" + first
            why = first[:160]
        rows.append((order, name, f"  ❌ {label}  {name}\n       {why}"))

# S 系列里因为空还没填、没有运行的测试
for t in skipped:
    name = re.sub(r"^test_", "", t)
    blanks = sorted({f"{m.upper()}-{n}" for n in re.findall(m + r"_(\d+)", name) if n != "0"},
                    key=lambda b: int(b.split("-")[1]))
    if not blanks or any(r[1] == name for r in rows):
        continue
    failed += 1
    rows.append((int(blanks[0].split("-")[1]), name, f"  ⬜ {', '.join(blanks)}  {name}\n       还没填，没有运行"))

for _, _, line in sorted(rows):
    print(line)

if not rows:
    print(f"没有跑到 {m.upper()} 的测试，完整日志见 {log_path}")
    sys.exit(1)
print()
print("全部通过 🎉" if failed == 0 else
      f"{failed} 个未通过。卡住先看 ../hints/ios-{m.upper()}.md，完整日志 {log_path}")
sys.exit(1 if failed else 0)
PY
