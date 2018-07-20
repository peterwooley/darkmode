# darkpaper

Set different macOS wallpapers at sunrise and sunset

This shell script pulls sunrise and sunset data from the Yahoo weather API and automates the setting up of two user launch agents for sunrise and sunset, which then take over running the script thereafter. If your mac was asleep/off during the solar times, launchd will run the script when you're next logged in!

This project is forked from [katernet's great darkmode project](https://github.com/katernet/darkmode).

### Usage
At sunrise, the script set's your wallpaper to an image found at `~/Pictures/sunrise-wallpaper.jpg`. At sunset, it looks for `~/Pictures/sunrise-wallpaper.jpg`. You can either move and rename your existing wallpaper images, or use a symlink, like so:
```
$ ln -s /path/to/your/sunrise-wallpaper.jpg ~/Pictures/sunrise-wallpaper.jpg
$ ln -s /path/to/your/sunset-wallpaper.jpg ~/Pictures/sunset-wallpaper.jpg
```

Once your wallpapers are in place, clone this repo, and run the script to install:
```
$ ./darkpaper.sh
```
 
### Notes

This script pulls your location from ipinfo.io. If you would not like the script to gather your location, hard code your location in the solar function in variables 'loc' (city) and 'nat' (nation) e.g. loc=seattle nat=usa

A log file is stored in `~/Library/Logs` which logs solar time changes and script errors.

To uninstall:
```
$ ./darkpaper.sh /u
```
