#!/usr/bin/env bash
# 人像精修工作流（Z-Image Turbo 低重绘三连采样）一键安装：插件 + 模型
# 在租来的 Linux GPU 机器上运行：bash install.sh [ComfyUI 目录]
# 可重复运行：已装好的插件、已下完的模型会跳过；模型下载中断后重跑会接着下。

[ -f /etc/network_turbo ] && source /etc/network_turbo >/dev/null 2>&1
set -euo pipefail

COMFY="${1:-}"
if [ -z "$COMFY" ]; then
  for d in /root/ComfyUI /root/autodl-tmp/ComfyUI /workspace/ComfyUI "$HOME/ComfyUI" /opt/ComfyUI; do
    if [ -f "$d/main.py" ]; then COMFY="$d"; break; fi
  done
fi
if [ -z "$COMFY" ] || [ ! -f "$COMFY/main.py" ]; then
  echo "❌ 找不到 ComfyUI 目录。请这样运行：bash $0 /你的/ComfyUI路径"
  exit 1
fi
PY="${PYTHON:-python3}"
command -v python >/dev/null 2>&1 && PY="${PYTHON:-python}"
echo "✅ ComfyUI 目录：$COMFY"
echo "✅ Python：$($PY --version 2>&1)"

need_gb=22
free_gb=$(df -Pk "$COMFY/models" | awk 'NR==2{print int($4/1048576)}')
echo "   模型目录剩余空间：${free_gb}GB（需要约 ${need_gb}GB）"

echo
echo "== 1/2 安装插件 =="
clone() {
  local name="$1" url="$2" dir="$COMFY/custom_nodes/$1"
  if [ -d "$dir" ]; then
    echo "   已存在 $name，跳过"
  else
    git clone --depth 1 "$url" "$dir"
  fi
  if [ -f "$dir/requirements.txt" ]; then
    $PY -m pip install -q -r "$dir/requirements.txt"
  fi
}
clone ComfyUI_essentials   https://github.com/cubiq/ComfyUI_essentials
clone ComfyUI_JPS-Nodes    https://github.com/JPS-GER/ComfyUI_JPS-Nodes
clone comfy-plasma         https://github.com/Jordach/comfy-plasma
clone comfyui-various      https://github.com/jamesWalker55/comfyui-various

echo
echo "== 2/2 下载模型（约 20.7GB）=="
HF="${HF_ENDPOINT:-https://huggingface.co}"
if ! curl -sI --max-time 10 "$HF" >/dev/null 2>&1; then
  HF="https://hf-mirror.com"
fi
echo "   下载源：$HF"
REPO="$HF/Comfy-Org/z_image_turbo/resolve/main/split_files"

dl() {
  local src="$1" dest="$2"
  if [ -s "$dest" ]; then
    echo "   已存在 $(basename "$dest")，跳过"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  echo "   下载 $(basename "$dest") ..."
  curl -L --fail --retry 5 -C - -o "$dest.part" "$REPO/$src"
  mv "$dest.part" "$dest"
}
M="$COMFY/models"
dl diffusion_models/z_image_turbo_bf16.safetensors "$M/diffusion_models/z_image_turbo_bf16.safetensors"
dl text_encoders/qwen_3_4b.safetensors             "$M/text_encoders/qwen_3_4b.safetensors"
# 工作流里 VAE 名字叫 FLUX.1-vae.sft，就是 Z-Image 官方的 ae.safetensors，按工作流里的名字保存
dl vae/ae.safetensors                              "$M/vae/FLUX.1-vae.sft"

echo
echo "🎉 安装完成。请重启 ComfyUI 让新插件生效。"
echo "   如果平台没有自带启动按钮，可以运行："
echo "   cd \"$COMFY\" && $PY main.py --listen 0.0.0.0 --port 6006"
