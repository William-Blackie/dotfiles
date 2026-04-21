#! /bin/zsh
##### Kubernetes helpers
if command -v kubectl >/dev/null 2>&1; then
    alias k="kubectl"

    kkx() {
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ fzf not found. Install it: brew install fzf"
            return 1
        fi
        local ctx
        ctx=$(kubectl config get-contexts -o name | fzf --header "Switch Kube Context" --reverse)
        [[ -n "$ctx" ]] && kubectl config use-context "$ctx"
    }

    kkn() {
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ fzf not found."
            return 1
        fi
        local ns
        ns=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | fzf --header "Switch Kube Namespace" --reverse)
        [[ -n "$ns" ]] && kubectl config set-context --current --namespace="$ns"
    }

    kkl() {
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ fzf not found."
            return 1
        fi
        local pod
        pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | fzf --header "Tail Pod Logs" --reverse)
        [[ -n "$pod" ]] && kubectl logs -f "$pod"
    }
fi
