set -ex

if command -v apt-get &> /dev/null
then
  sudo apt-get update
  sudo apt-get install -y xvfb
fi

ulimit -n 4096

# Check if xfvb is installed
if ! command -v Xvfb > /dev/null; then
  if ! test "$ZEN_CROSS_COMPILING"; then
    Xvfb :2 -screen 0 1024x768x24 &
    export LLVM_PROFDATA=$HOME/.mozbuild/clang/bin/llvm-profdata
    export DISPLAY=:2
  fi
else
  echo "Xvfb could not be found, running without it"
  echo "ASSUMING YOU ARE RUNNING THIS ON MACOS"
  set -v
fi

env ZEN_RELEASE=${ZEN_RELEASE:-} pnpm build 
