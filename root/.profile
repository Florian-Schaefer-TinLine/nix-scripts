if [ -z "$TMUX" ]; then
    if tmux has-session -t setupSession 2>/dev/null; then
        tmux attach-session -t setupSession
    elif tmux has-session -t dotnetSession 2>/dev/null; then
        tmux attach-session -t dotnetSession
    fi
fi