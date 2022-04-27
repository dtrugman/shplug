![shplug](./img/shplug.png "Logo")

**Your new shell plugin manager** - An easy solution for managing your shell environments.

There are two main use patterns:

## Synced environments

Sync your files across multiple environments (aka machines) using a simple git repository.

### Example

Let's say you have 2 different machines you use for development/administration/etc.
You wanna sync your dotfiles: `.gitconfig`, `.vimrc`, `.bashrc`, `.tmux.conf`
and possibly some scripts you always find useful to have on your machine.

Create a git repository, call it however you like and use the following structure:
- [git-repo-root]
    - install
    - home
        - .gitconfig
        - .vimrc
        - .bashrc
        - .tmux.conf
        - scripts
            - my_greatest_script.sh
            - my_awesome_script.rb
            - my_amazing_tool.py

Once you have `shplug` installed on your machine, you can get all those goodies using a single command:
```
shplug env add <env-name> <git-repo-url>
```

For example, I clone my [dotfiles](https://github.com/dtrugman/dotfiles) using:
```
shplug env add dotfiles https://github.com/dtrugman/dotfiles
```

When you run the command, the following will happen:

1. The repository will be cloned locally into some hidden directory under your user's home (The user that executes the `shplug env add` command)
1. All the files are going to be linked under your actual `$HOME` directory. Existing files are going to be backed-up and only then overriden. **Don't worry, you will be notified of the changes and prompted for approval.**
1. The `install` script is going to be executed, just in case you want to automatically add the new `scripts` directory into your `$PATH` without any additional manual steps, install `plug.vim` and run `:PlugInstall` or do anything else automatically every time you sync the environment.

Notes:
1. The `install` file is optional
1. `home` is a hard-coded keyword for the `$HOME` of the user that will be using the environment. `scripts` is just an arbitrary name you can use. Any other name will work as well
1. You can use other root-level directories in your repository, as in, have an `app` directory next to `home`. When calling `shplug env add`, it will try to create and link those files under `/app` on your machine. Make sure that this directory exists and owned by your user, otherwise `shplug add env` will fail due to lack of permissions to create a directory under `/`.
    - Another option is to run the command as a superuser while retaining your user's `$HOME` configuration. This might work but will definitely require further `chown`-s to fix the permissions on all the cloned files, hence ill-advised.

### Plan on changing your scripts? Great!

You can edit any of your scripts and push them to your global git repository easily. After doing any changes, just enter the hidden git repo using: `shplug env cd <env-name>`, and interact directly with your git repository.

## Easy plugins

Quickly and easily manage aliases, functions, gists and more. The plugin manager allows you to download files locally and automatically source them into your active shell.

Let's say a colleague wrote a small script to handle that annoying task that broke the integration tests at work. Just get him to upload it anywhere and run: `shplug plugin add <plugin-name> <plugin-url>`.

The name can be whatever you want. Here's an example: `shplug plugin add git-describe https://gist.github.com/dtrugman/ec4d40e7b05f01251e4c688ae62219fd`

You could argue you can just add this script to your dotfiles repo, but life's dynamic and unexpected. There are different reasons to keep those separated:

- You might decide to keep your dotfiles private while share some scripts with colleagues or fellow redditors
- You wanna try scripts out before adding them to your repo
- You want an easy way to add an alias/function/script for a limited time, say, while doing a demo

## Install

`shplug` currently officially supports `bash` and `zsh`:

bash:
```
curl -L "https://github.com/dtrugman/shplug/releases/download/v0.1.0/install_bash" | bash && source "$HOME/.bashrc"
```

zsh:
```
curl -L "https://github.com/dtrugman/shplug/releases/download/v0.1.0/install_zsh" | zsh && source "$HOME/.zshrc"
```

## Feature requests & Contributions

You are more than welcome to ask/do both!
