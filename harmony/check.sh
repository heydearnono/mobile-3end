#!/usr/bin/env bash
# 填空检查：./check.sh M1（里程碑）或 ./check.sh A1（ArkTS 语言专项）
# 1. 列出还没填的空（代码里剩下的 TODO('M1-n')）
# 2. 跑本地单测（entry/src/test，不需要设备）+ 设备测试（entry/src/ohosTest，需要模拟器 / 真机且已签名），按空汇总结果
#    A 系列全是本地单测，不跑设备测试
set -uo pipefail

M="${1:-}"
if [[ ! "$M" =~ ^[MA][0-9]+$ ]]; then
  echo "用法：./check.sh M1 或 ./check.sh A1" >&2
  exit 2
fi
m="$(echo "$M" | tr 'MA' 'ma')"
cd "$(dirname "$0")"

# 命令行工具都在 DevEco Studio 里，不在 PATH 上。DevEco 装在别处时先 export DEVECO=...
DEVECO="${DEVECO:-/Applications/DevEco-Studio.app/Contents}"
export NODE_HOME="${NODE_HOME:-$DEVECO/tools/node}"            # hvigorw 用它找 node
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO/sdk}"       # hvigor 找 SDK（sdk/default 下的 openharmony + hms）
export JAVA_HOME="${JAVA_HOME:-$DEVECO/jbr/Contents/Home}"     # PackageHap / SignHap 调 java 打包签名
export PATH="$NODE_HOME/bin:$DEVECO/tools/ohpm/bin:$DEVECO/tools/hvigor/bin:$DEVECO_SDK_HOME/default/openharmony/toolchains:$PATH"
LOG=/tmp/m3e-harmony-check.log
: >"$LOG"

# 离线包：rawfile 不能引用工程外的文件，每次从 ../mock/h5 同步一份
./sync-h5.sh

if [[ ! -d oh_modules ]]; then
  echo "== 首次运行：ohpm install"
  ohpm install >>"$LOG" 2>&1 || { echo "ohpm install 失败，见 $LOG"; exit 1; }
fi

echo "== 未填的空"
# 跳过被注释掉的 TODO（把原空注释保留下来对照也算已填）
left="$(grep -rnE "TODO\('$M-[0-9]+'\)" entry/src/main/ets | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' | sed -E "s#^([^:]+:[0-9]+:).*TODO\('([^']+)'\).*#\1\2#" | sed -E 's#entry/src/main/ets/##')"
if [[ -z "$left" ]]; then
  echo "（无）"
else
  echo "$left" | awk -F: '{ printf "  %-8s %s:%s\n", $3, $1, $2 }' | sort -t- -k2 -n
fi

# ArkTS 编译错误：把 hvigor 的彩色输出洗干净，只留错误信息
compile_errors() {
  sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -E '^Error Message:' | sed -E 's#^Error Message: ##; s# At File: .*/harmony/# @ #'
}

echo
echo "== 运行本地单测（约 10s，首次较慢）"
UNIT=entry/.test/default/intermediates/test/coverage_data/test_result.txt
rm -f "$UNIT"
hvigorw --mode module -p module=entry@default -p product=default test --no-daemon >>"$LOG" 2>&1
if [[ ! -f "$UNIT" ]]; then
  errs="$(compile_errors "$LOG")"
  echo "编译失败："
  if [[ -n "$errs" ]]; then echo "$errs" | sed 's/^/  /'; else echo "  （没有解析到 ArkTS 错误，完整日志见 $LOG）"; fi
  exit 1
fi

DEVICE_OUT=/tmp/m3e-harmony-device.txt
rm -f "$DEVICE_OUT"
target="$(hdc list targets 2>/dev/null | grep -v '\[Empty\]' | head -1)"
if [[ "$M" == A* ]]; then
  :  # 语言专项只有本地单测
elif [[ -z "$target" ]]; then
  echo "没有连接的设备 / 模拟器（hdc list targets 为空），只跑本地单测。"
  echo "在 DevEco 的 Device Manager 里启动模拟器后重跑，可检查 UI / 设备相关的空"
else
  echo
  echo "== 运行设备测试（$target，约 1–2 分钟）"
  hvigorw --mode module -p product=default assembleHap --no-daemon >>"$LOG" 2>&1 &&
    hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon >>"$LOG" 2>&1
  app_hap="$(ls entry/build/default/outputs/default/*-signed.hap 2>/dev/null | head -1)"
  test_hap="$(ls entry/build/default/outputs/ohosTest/*-signed.hap 2>/dev/null | head -1)"
  if [[ -z "$app_hap" || -z "$test_hap" ]]; then
    errs="$(compile_errors "$LOG")"
    if [[ -n "$errs" ]]; then
      echo "编译失败："; echo "$errs" | sed 's/^/  /'; exit 1
    fi
    echo "没有找到签名过的 HAP：设备只能安装签名包。先按 hints/harmony-M0.md 在 DevEco 里配置自动签名，跳过设备测试"
  else
    hdc -t "$target" uninstall com.example.mobile3end >>"$LOG" 2>&1
    hdc -t "$target" install "$app_hap" >>"$LOG" 2>&1
    hdc -t "$target" install "$test_hap" >>"$LOG" 2>&1
    hdc -t "$target" shell aa test -b com.example.mobile3end -m entry_test \
      -s unittest /ets/testrunner/OpenHarmonyTestRunner -s timeout 30000 >"$DEVICE_OUT" 2>&1
    cat "$DEVICE_OUT" >>"$LOG"
  fi
fi

echo
echo "== 结果"
python3 -I - "$m" "$UNIT" "$DEVICE_OUT" <<'PY'
import os, re, sys

m, unit, device = sys.argv[1], sys.argv[2], sys.argv[3]

def parse_unit(path):
    """本地单测：test=<名字> / 若干行错误 / result=Success|Failure|Error"""
    out, cur, buf = [], None, []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("test="):
            cur, buf = line[5:], []
        elif line.startswith("result=") and cur is not None:
            out.append((cur, line[7:] == "Success", "\n".join(buf)))
            cur = None
        elif cur is not None:
            buf.append(line)
    return out

def parse_device(path):
    """aa test 的输出：每个用例一组 OHOS_REPORT_STATUS，CODE 0 通过，-1 / -2 失败（错误在 stream=）"""
    out, test, stream = [], None, ""
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line.startswith("OHOS_REPORT_STATUS: test="):
            test = line.split("=", 1)[1]
        elif line.startswith("OHOS_REPORT_STATUS: stream="):
            stream = line.split("=", 1)[1]
        elif line.startswith("OHOS_REPORT_STATUS_CODE:") and test is not None:
            code = int(line.split(":", 1)[1])
            if code == 1:  # 用例开始
                stream = ""
                continue
            out.append((test, code == 0, stream))
            test = None
    return out

cases = parse_unit(unit)
if os.path.exists(device):
    cases += parse_device(device)

failed = 0
rows = []
for name, ok, text in cases:
    if not name.startswith(m + "_"):
        continue
    blanks = sorted({f"{m.upper()}-{n}" for n in re.findall(m + r"_(\d+)", name) if n != "0"},
                    key=lambda b: int(b.split("-")[1]))
    label = ", ".join(blanks) or ("综合" if "e2e" in name else "示例")
    order = int(blanks[0].split("-")[1]) if blanks else (99 if "e2e" in name else 0)
    if ok:
        rows.append((order, name, f"  ✅ {label}  {name}"))
        continue
    failed += 1
    todo = re.search(r"An operation is not implemented: ([MA]\d+-\d+)", text)
    if todo:
        why = f"运行到了未填的 {todo.group(1)}"
    else:
        first = next((l for l in text.splitlines() if l.strip()), "")
        why = re.sub(r"^Error in \S+, ", "", first)[:160]
    rows.append((order, name, f"  ❌ {label}  {name}\n       {why}"))

if not rows:
    print(f"没有找到 {m.upper()} 的测试结果，完整日志见 /tmp/m3e-harmony-check.log")
    sys.exit(1)
for _, _, line in sorted(rows):
    print(line)

print()
print("全部通过 🎉" if failed == 0 else
      f"{failed} 个未通过。卡住先看 ../hints/harmony-{m.upper()}.md，完整日志 /tmp/m3e-harmony-check.log")
sys.exit(1 if failed else 0)
PY
