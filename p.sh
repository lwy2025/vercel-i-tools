#!/bin/bash

# 一键推送脚本 - i-tools项目
# 作者: 自动生成
# 功能: 添加所有更改、提交并推送到远程仓库

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "当前目录不是git仓库！"
    exit 1
fi

# 检查是否有未提交的更改
if git diff --quiet && git diff --cached --quiet; then
    print_warning "没有检测到任何更改，无需提交。"
    exit 0
fi

print_info "开始推送流程..."

# 获取当前分支
current_branch=$(git branch --show-current)

# 分支检查和处理
if [ "$current_branch" != "main" ]; then
    print_warning "当前分支是 '$current_branch'，自动切换到main分支。"
    
    # 暂存当前更改（如果有的话）
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_info "暂存当前分支的更改..."
        git stash push -m "deploy.sh自动暂存-$(date +%s)"
    fi
    
    # 切换到main分支
    git checkout main
    
    # 恢复暂存的更改（如果有的话）
    if git stash list | head -1 | grep -q "deploy.sh自动暂存"; then
        print_info "恢复暂存的更改..."
        git stash pop
    fi
    
    print_success "已切换到main分支"
    current_branch="main"
fi

# 显示当前状态
print_info "当前git状态:"
git status --short

# 获取提交消息
if [ $# -eq 0 ]; then
    commit_msg="自动更新"
else
    commit_msg="$*"
fi

# 添加所有更改
print_info "添加所有更改到暂存区..."
git add .

# 提交更改
print_info "提交更改..."
git commit -m "$commit_msg"

# 分支检查和处理
if [ "$current_branch" != "main" ]; then
    print_warning "当前分支是 '$current_branch'，只有main分支才能推送。"
    print_info "将自动切换到main分支并合并当前更改。"
    
    # 检查是否有未提交的更改
    if ! git diff --quiet || ! git diff --cached --quiet; then
        read -p "是否将 '$current_branch' 分支的更改合并到main分支？(y/N): " merge_changes
        if [[ $merge_changes =~ ^[Yy]$ ]]; then
            print_info "暂存当前分支的更改..."
            git add .
            git commit -m "临时提交: 从 $current_branch 分支的更改" || true
            
            print_info "切换到main分支..."
            git checkout main
            
            print_info "合并 $current_branch 分支到main..."
            git merge "$current_branch" --no-ff -m "合并分支: $current_branch -> main"
            
            print_info "删除临时提交..."
            git reset --soft HEAD~2  # 撤销临时提交和合并提交
            git reset HEAD  # 取消暂存
        else
            print_info "切换到main分支..."
            # 暂存当前更改
            if ! git diff --quiet || ! git diff --cached --quiet; then
                git stash push -m "deploy.sh自动暂存-$(date +%s)"
            fi
            git checkout main
            
            # 恢复暂存的更改
            if git stash list | head -1 | grep -q "deploy.sh自动暂存"; then
                print_info "恢复暂存的更改..."
                git stash pop
            fi
        fi
    else
        print_info "切换到main分支..."
        git checkout main
    fi
    
    print_success "已切换到main分支"
    current_branch="main"
fi

# 拉取最新代码（确保本地是最新的）
print_info "拉取远程main分支最新代码..."
git pull origin main --rebase

# 推送到远程仓库
print_info "推送到远程仓库 ($current_branch)..."
git push origin "$current_branch"

print_success "推送完成！"
echo ""
print_info "提交信息: $commit_msg"
print_info "分支: $current_branch"
print_info "远程仓库: origin"

# 运行构建测试
print_info "运行构建测试..."
if npm run build; then
    print_success "构建测试通过！"
else
    print_error "构建测试失败！"
    exit 1
fi

print_success "所有操作完成！🎉"