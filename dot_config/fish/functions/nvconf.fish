function nvconf

    if test "$argv[1]" = --up
        set config_dir ~/.config/nvim
        echo "Updating Neovim Config..."
        git -C $config_dir pull
        echo "Update is Done"

    else
        # Defaults to change to directory, update and open
        echo "Moving to Neovim"
        cd ~/.config/nvim/
        echo "Updating Neovim"
        git pull
        echo "Opening Neovim"
        nvim $argv
    end
end
