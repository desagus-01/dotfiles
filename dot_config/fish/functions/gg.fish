function gg -d "Add all file, commits and pushes to repo"

    git add .

    if test (git diff --cached --quiet) -a (git diff --quiet)
        echo "No changes to commit."
        return 0
    end

    git commit -m "$argv"
    git push

end
