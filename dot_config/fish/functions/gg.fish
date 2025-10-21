function gg -d "Add all file, commits and pushes to repo"

    git add .
    git commit -m "$argv"
    git push

end
