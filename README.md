<div align='center'>
  <div>
    <img src="https://forthebadge.com/images/badges/for-you.svg"/> 
    <img src="https://forthebadge.com/images/badges/built-with-love.svg"/> 
    <img src="https://forthebadge.com/images/badges/uses-badges.svg"/>
  </div>
</div>

# simon

Are you also love artworks of [Simon Stålenhag][twitter] but tired to keep
searching all over his [site][] to find any updates because it's heavy and
organize not well enough? The project is for you! It ships with
[`simon.sh`](simon.sh) script that helps to detect any changes on a home
page of the site and tries to download all images it's able to find.

![demo.gif](https://user-images.githubusercontent.com/10958284/53495757-7a220280-3a98-11e9-8259-71c22bbe1b5a.gif)

[twitter]: https://twitter.com/simonstalenhag?lang=en
[site]: http://simonstalenhag.se

## Getting Started

Clone the project into a directory of your choice and `cd` to `simon` folder:

```shell
git clone "https://github.com/7aitsev/simon.git"
cd simon
```

or find on the page "Clone or download" button, press on it and download
a ZIP archive. Extract the archive with `unzip` tool as shown below:

```shell
unzip simon-master.zip
cd simon-master
```

### Prerequisites

The script should run fine on a GNU/Linux distributive in any POSIX®-compliant
shells like BASH, Zsh or DASH. Either `curl` or `wget` required to be
installed as well as `sed`. If you are not sure whether or not these
utilities are installed, the script will generate descriptive messages
about which of the programs you missed.

### Installing

Installation is not required. But you can place the script under
`/usr/local/bin/` like this:

```shell
# cd to the repo's folder
sudo install -m 0555 -o root -g root simon.sh /usr/local/bin/simon
```

Note that the last command uses `sudo` as it has to have root privileges
in order to be successfully executed.

## Usage

There are two modes implemented in the script: interactive and
automatic (non-interactive). The former mode is the default. It allows you to
manually walk through all prompts and decide whether to do something or not.

For now, let's assume that you installed the script so it's possible to just
run `simon` from a command line (if not, use `./simon.sh` instead of just
`simon` while in the project's directory).

### Common Options

The script keeps a snapshot of the site in order to compare a new snapshot
with the old one. The snapshot is stored as SNAPSHOT_OLD, but you can
specify another path to the file:

```
simon -s ~/.cache/simon/simon.old
```

You may want to set a directory where all downloaded images will be stored:

```
simon -i ~/Pictures/Simon
```

Use `-c` option to disable color output and text formatting.

If this is the mode you want to use regulary and don't want to provide
`-i` and `-s` options with their arguments, create an alias as the following:

```shell
alias simon='simon -i <your_dir> -s <your_path>'
```

Refer to your shell documentation to find out where the alias should be
placed in order to use it not only for a current shell session.

### Interactive Mode

As previously mentioned, this is the default mode. You don't need to provide
any special options here.

It may be helpful to use `-h` option to show a short summary of all the
options.

### Non-interactive Mode

This mode is useful if you want to run the script at scheduled times using
cron daemon of your choice or using systemd timers. The script does not
produce any outputs except for errors (`stderr`).

To enter the mode, specify `-a` option. If you want to disable errors outputs,
use `-q` option. If you want to see not only errors, use `-v` option
that enables regular messages (`stdout`), i.e. the command below will produce
almost the same output as it does in the interactive mode:

```
simon -av
```

In interactive mode, you are able to see diff output between the snapshots. To
enable the output in the automatic mode use a combination of `-v` *and* `-d`
options, e.g.:

```
simon -avd
```

Now, last but perhaps not least, it makes sense to *disable* the use of
colored output with `-c` option.

#### Set up a cron-job

todo

#### Set up a systemd timer

todo

## Contributing

Feel free to open an issue with any questions or problems related to the
project. Any ideas or pull requests would be welcomed.

Please note that **simon** is my silly project so do not have high
expectations of all of this...

![my_project](https://user-images.githubusercontent.com/10958284/53481312-da06b200-3a74-11e9-8137-d333d534d516.jpg)

## Acknowledgments

Thanks to all of you who starred the project and hit the ~~subscribe~~ watch
button.
