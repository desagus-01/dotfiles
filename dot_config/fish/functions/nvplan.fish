function nvplan
    set -l config_dir ~/Documents/personal/planning

    # If --up is anywhere in the args, just sync and exit
    if contains -- --up $argv
        echo "Syncing your Notes"
        git -C $config_dir pull >/dev/null 2>&1; and echo "Done!!"
        return
    end

    echo "Moving to Notes dir..."
    cd $config_dir; or return

    echo "Syncing Notes..."
    git pull >/dev/null 2>&1; and echo "Opening Notes"

    # Open Neovim with any args passed (since --up path already returned)
    nvim $argv
end
