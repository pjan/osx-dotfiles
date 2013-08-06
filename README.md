# osx-dotfiles

## Installation

### Using Git and the bootstrap script

The repository can be cloned in whichever location. The bootstrap script will [git] pull the latest version and _overwrite_ the files in your homefolder.

```bash
git clone --recursive https://github.com/pjan/osx-dotfiles.git && cd osx-dotfiles && source bootstrap.sh
```

To update, `cd` into the local `osx-dotfiles` folder and execute:

```bash
source bootstrap.sh
```

Any confirmation prompt can be avoided by executing:

```bash
set -- -f; source bootstrap.sh
```

### Custom path modifications

`~/.path` gets sourced along the others (before). It can be used to set the path, without risking it to be overwritten when running the update.


### Custom commands

`~/.extra` gets sourced along the others (after). It can be used to add custom commands, without risking them to be lost when running the update.

Add the same time, it can be used to override aliases, functions, settings from the repository.

### OS X defaults

To load a new set of (better) defaults after setting up your Mac, update the config file in your home folder, then execute:

```bash
./.setdefaults
```

### Binaries & applications

When setting up your mac, you can automatically update & add binaries, and install a set of standard applications by executing:

```
./.brew
```

## Feedback

Is [welcome](https://github.com/pjan/osx-dotfiles/issues)!

## Credits

* [Ben Alman](http://benalman.com/) for his [dotfiles repo](https://github.com/cowboy/dotfiles)
* [Ethan Schoonover](http://ethanschoonover.com) for his [solarized color scheme](http://ethanschoonover.com/solarized)
* [Lauri Ranta](http://lri.me/) for instructing me about [hidden preferences](http://lri.me/osx.html#hidden-preferences)
* [Mathias Bynens](https://github.com/mathiasbynens) for his extensive [dotfiles repo](https://github.com/mathiasbynens/dotfiles)
* [Matijs Brinkhuis](http://hotfusion.nl/) for his [dotfiles repo](https://github.com/matijs/dotfiles)
* [Tom Ryder](http://blog.sanctum.geek.nz/) for his [dotfiles repo](https://github.com/tejr/dotfiles)


