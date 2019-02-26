<div align='center'>
  <div>
    <img src="https://forthebadge.com/images/badges/for-you.svg"/> 
    <img src="https://forthebadge.com/images/badges/built-with-love.svg"/> 
    <img src="https://forthebadge.com/images/badges/uses-badges.svg"/>
  </div>
</div>

# simon

Are you also love artworks of [Simon Stålenhag][twitter] but tired to keep searching all over his [site][] to find any updates because it's heavy and organize not well enough? The project is for you! It ships with [`simon.sh`](simon.sh) script that helps to detect any changes on a home page of the site and tries to download all images it's able to find.

[twitter]: https://twitter.com/simonstalenhag?lang=en
[site]: http://simonstalenhag.se

## Getting Started

Clone the project to wherever you want as shown below:

```shell
cd ~/Downloads/
git clone "https://github.com/7aitsev/simon.git"
```

or find on the page "Clone or download" button, press on it and download a ZIP archive.

### Prerequisites

The script should run fine on a GNU/Linux distributive in any POSIX®-compliant shell like BASH, Zsh or DASH. You also need either `curl` or `wget` to be installed as well as `sed`. If you are not sure whether or not those utilities are installed, the script will generate descriptive messages about which of the programs you missed.

### Installing

Installation is not required. But you cat place the script under `/usr/local/bin/` like this:

```shell
# cd to the repo's folder
sudo install -m 0555 -o root -g root simon.sh /usr/local/bin/simon
```

You have to have root privileges in order to successfully run the last command above.

## Usage:

```
simon [OPTIONS]
```

OPTIONS

* `-a` - enter non-interactive (automatic) mode: download anything that's possible and exit.
* `-c` - disable colors.
* `-i directory` - specify a *directory* for storing images (default is IMAGES_DIR[\[1\]](#ref)). The directory has to exist.
* `-s path` - specify a *path* to an old snapshot (default is SHAPSHOT_OLD[\[1\]](#ref)). Create the snapshot with the name specified in *path* if the snapshot doesn't exist. A directory tree in *path* has to exist.

There are two modes. If the following options are used in a not appropriate mode, the script execution fails.

INTERACTIVE MODE (the default):

* `??` - simplified output (like in non-interactive mode) [TODO]
* `-h` - print short version of the USAGE and exit

NON-INTERACTIVE MODE

The mode is silent by default, except for errors.

* `-v` - make the output more verbose, i.e. show regular messages about what's happening.
* `-q` - don't print errors. With `-v` - doesn't make any sense and therefore the combination is forbidden. Without `-v` - makes the script to run completely quiet.
* `-d` - log diff between an old snapshot and a new one (if `-v` is present).

<a name="ref"></a>
\[1\] will be clarified when the #6 issue is done

## Contributing

Feel free to open an issue with any questions or problems related to the project. Any ideas or pull requests would be welcomed.
