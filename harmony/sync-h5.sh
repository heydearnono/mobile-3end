#!/usr/bin/env bash
# 把 ../mock/h5 同步到 rawfile/h5。rawfile 只能放在 resources/rawfile 下，不能引用工程外的文件，
# 所以每次构建前同步一份；mock/h5 是唯一来源，不要直接改 rawfile/h5 里的文件。
# check.sh 会自动调用；在 DevEco 里直接点 Run 之前，改过 mock/h5 就手动跑一次
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p entry/src/main/resources/rawfile/h5
rsync -a --delete ../mock/h5/ entry/src/main/resources/rawfile/h5/
