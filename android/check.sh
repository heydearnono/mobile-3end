#!/usr/bin/env bash
# 填空检查：./check.sh M1（里程碑）/ ./check.sh K1（Kotlin 语言专项，纯 JVM 单测）
# 1. 列出还没填的空（代码里剩下的 TODO("M1-n")）
# 2. 跑 JVM 单测 + 模拟器 UI 测试，按空汇总结果
set -uo pipefail

M="${1:-}"
if [[ ! "$M" =~ ^[MK][0-9]+$ ]]; then
  echo "用法：./check.sh M1 或 ./check.sh K1" >&2
  exit 2
fi
m="$(echo "$M" | tr 'MK' 'mk')"
cd "$(dirname "$0")"

# 命令行没有系统 JDK 时，用 Android Studio 自带的
if [[ -z "${JAVA_HOME:-}" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

echo "== 未填的空"
# 跳过被注释掉的 TODO（把原空注释保留下来对照也算已填）
left="$(grep -rnE "TODO\(\"$M-[0-9]+\"\)" app/src/main/java | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' | sed -E 's#^([^:]+:[0-9]+:).*(TODO\("[^"]+"\)).*#\1\2#' | sed -E 's#app/src/main/java/com/example/mobile3end/##; s#TODO\("(.*)"\)#\1#')"
if [[ -z "$left" ]]; then
  echo "（无）"
else
  echo "$left" | awk -F: '{ printf "  %-8s %s:%s\n", $3, $1, $2 }' | sort -t- -k2 -n
fi

echo
echo "== 运行测试（首次较慢）"
ui_tests=1
if [[ "$M" == K* ]]; then
  ui_tests=0
elif ! adb get-state >/dev/null 2>&1; then
  echo "没有连接的设备 / 模拟器，只跑 JVM 单测。启动模拟器后重跑可检查 UI 相关的空"
  ui_tests=0
fi

rm -rf app/build/test-results/testDebugUnitTest app/build/outputs/androidTest-results/connected
tasks=(testDebugUnitTest --tests "*${M}*")
if [[ $ui_tests == 1 ]]; then
  tasks+=(connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=com.example.mobile3end.${M}UiTest")
fi
./gradlew --console=plain --quiet --continue "${tasks[@]}" >/tmp/m3e-check.log 2>&1
if grep -q '^e: ' /tmp/m3e-check.log; then
  echo "编译失败："
  grep '^e: ' /tmp/m3e-check.log | sed -E 's#file://.*/mobile3end/##'
  exit 1
fi

echo
echo "== 结果"
python3 -I - "$m" <<'PY'
import glob, re, sys, xml.etree.ElementTree as ET

m = sys.argv[1]
files = glob.glob("app/build/test-results/testDebugUnitTest/*.xml") + \
        glob.glob("app/build/outputs/androidTest-results/connected/**/*.xml", recursive=True)
if not files:
    print("没有找到测试结果，完整日志见 /tmp/m3e-check.log")
    sys.exit(1)

failed = 0
rows = []
for f in sorted(files):
    for c in ET.parse(f).getroot().iter("testcase"):
        name = c.get("name").split("[")[0]
        if not name.startswith(m + "_"):
            continue
        blanks = sorted({f"{m.upper()}-{n}" for n in re.findall(m + r"_(\d+)", name) if n != "0"})
        label = ", ".join(blanks) or ("综合" if "e2e" in name else "示例")
        fail = c.find("failure")
        order = int(blanks[0].split("-")[1]) if blanks else (99 if "e2e" in name else 0)
        if fail is None:
            rows.append((order, name, f"  ✅ {label}  {name}"))
            continue
        failed += 1
        text = fail.text or fail.get("message") or ""
        todo = re.search(r'An operation is not implemented: ([MK]\d+-\d+)', text)
        if todo:
            why = f"运行到了未填的 {todo.group(1)}"
        else:
            first = next((l for l in text.splitlines() if l.strip()), "")
            why = re.sub(r"^(java\.lang\.)?\w+(\.\w+)*Error: ", "", first)[:160]
        rows.append((order, name, f"  ❌ {label}  {name}\n       {why}"))

for _, _, line in sorted(rows):
    print(line)

print()
print("全部通过 🎉" if failed == 0 else f"{failed} 个未通过。卡住先看 ../hints/{m.upper()}.md，完整日志 /tmp/m3e-check.log")
sys.exit(1 if failed else 0)
PY
