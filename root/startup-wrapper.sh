#!/bin/sh
echo "🔄 Running startup sequence..."

# Run setup script if it hasn't completed
if [ ! -f "/root/.setup-done" ]; then
    echo "⚠️ Setup script needs to be executed. Running now..."
    tmux new-session -s setupSession "/root/setup-net-vm.sh"
    echo "✅ Setup complete! Closing setup session..."
    tmux kill-session -t setupSession
fi

# Kill any existing `dotnetSession` to prevent conflicts
tmux kill-session -t dotnetSession 2>/dev/null

# Create a new tmux session for split panes
tmux new-session -s dotnetSession -d

# Split the screen into two horizontal panes
tmux split-window -h

# Select the left pane and run the .NET app
tmux select-pane -t 0
tmux send-keys "/root/start-dotnet-console.sh" C-m

# Select the right pane and keep it as an interactive shell
tmux select-pane -t 1

tmux send-keys "tmux source-file /root/.tmux.conf" C-m
tmux send-keys "clear" C-m

# Attach to the split tmux session
tmux attach-session -t dotnetSession