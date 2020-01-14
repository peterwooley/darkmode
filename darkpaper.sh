#!/bin/bash
#
## Dark wallpaper at sunset, light at sunrise
## Solar times pulled from Yahoo Weather API
## Dark Paper author: peterwooley
## Original Darkmode Author: katernet

## Global variables ##
darkdir=~/Library/Application\ Support/darkpaper # darkpaper directory
plistR=~/Library/LaunchAgents/io.github.peterwooley.darkpaper.sunrise.plist # Launch Agent plist locations
plistS=~/Library/LaunchAgents/io.github.peterwooley.darkpaper.sunset.plist

## Functions ##

# Set dark paper - Sunrise = off Sunset = on
darkpaper() {
	case $1 in
		off) 
			# Set sunrise wallpaper

			osascript -e '
      tell application "System Events"
        tell every desktop
          set picture to "~/Pictures/sunrise-wallpaper.jpg"
        end tell
      end tell
			'

			if ls /Applications/Alfred*.app >/dev/null 2>&1; then # If Alfred installed
				osascript -e 'tell application "Alfred 3" to set theme "Alfred"' 2> /dev/null # Set Alfred default theme
			fi
			if [ -f "$plistR" ] || [ -f "$plistS" ]; then # Prevent uninstaller from continuing
				# Run solar query on first day of week
				if [ "$(date +%u)" = 1 ]; then
					solar
				fi
				# Get sunset launch agent start interval time
				plistSH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistS" 2> /dev/null)
				plistSM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistS" 2> /dev/null)
				if [ -z "$plistSH" ] && [ -z "$plistSM" ]; then # If plist solar time vars are empty
					editPlist add "$setH" "$setM" "$plistS" # Run add solar time plist function
				elif [[ "$plistSH" -ne "$setH" ]] || [[ "$plistSM" -ne "$setM" ]]; then # If launch agent times and solar times differ
					editPlist update "$setH" "$setM" "$plistS" # Run update solar time plist function
				fi
			fi
			;;
		on)
			# Set sunset wallpaper
			osascript -e '
      tell application "System Events"
        tell every desktop
          set picture to "~/Pictures/sunset-wallpaper.jpg"
        end tell
      end tell
			'
      # Get sunrise launch agent start interval
			plistRH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistR" 2> /dev/null)
			plistRM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistR" 2> /dev/null)
			if [ -z "$plistRH" ] && [ -z "$plistRM" ]; then
				editPlist add "$riseH" "$riseM" "$plistR"
			elif [[ "$plistRH" -ne "$riseH" ]] || [[ "$plistRM" -ne "$riseM" ]]; then
				editPlist update "$riseH" "$riseM" "$plistR"
			fi
			;;
	esac
}

# Solar query
solar() {
	# Get Night Shift solar times (UTC)
	riseT=$(/usr/libexec/corebrightnessdiag nightshift-internal | grep nextSunrise | cut -d \" -f2)
	setT=$(/usr/libexec/corebrightnessdiag nightshift-internal | grep nextSunset | cut -d \" -f2)
	# Convert to local time
	riseTL=$(date -jf "%Y-%m-%d %H:%M:%S %z" "$riseT" +"%H:%M")
	setTL=$(date -jf "%Y-%m-%d %H:%M:%S %z" "$setT" +"%H:%M")
	# Store times in database
	sqlite3 "$darkdir"/solar.db <<EOF
	CREATE TABLE IF NOT EXISTS solar (id INTEGER PRIMARY KEY, time VARCHAR(5));
	INSERT OR IGNORE INTO solar (id, time) VALUES (1, '$riseTL'), (2, '$setTL');
	UPDATE solar SET time='$riseTL' WHERE id=1;
	UPDATE solar SET time='$setTL' WHERE id=2;
EOF
	# Log
	echo "$(date +"%d/%m/%y %T")" darkpaper: Solar query stored - Sunrise: "$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "")" Sunset: "$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "")" >> ~/Library/Logs/io.github.peterwooley.darkpaper.log
}

# Deploy launch agents
launch() {
	shdir="$(cd "$(dirname "$0")" && pwd)" # Get script path
	cp -p "$shdir"/darkpaper.sh "$darkdir"/ # Copy script to darkpaper directory
	mkdir ~/Library/LaunchAgents 2> /dev/null; cd "$_" || return # Create LaunchAgents directory (if required) and cd there
	# Setup launch agent plists
	/usr/libexec/PlistBuddy -c "Add :Label string io.github.peterwooley.darkpaper.sunrise" "$plistR" 1> /dev/null
	/usr/libexec/PlistBuddy -c "Add :Program string ${darkdir}/darkpaper.sh" "$plistR"
	/usr/libexec/PlistBuddy -c "Add :RunAtLoad bool true" "$plistR"
	/usr/libexec/PlistBuddy -c "Add :Label string io.github.peterwooley.darkpaper.sunset" "$plistS" 1> /dev/null
	/usr/libexec/PlistBuddy -c "Add :Program string ${darkdir}/darkpaper.sh" "$plistS"
	# Load launch agents
	launchctl load "$plistR"
	launchctl load "$plistS"
}

# Edit launch agent solar times
editPlist() {
	case $1 in
		add)
			# Unload launch agent
			launchctl unload "$4"
			# Add solar times to launch agent plist
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Hour integer $2" "$4"
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Minute integer $3" "$4"
			# Load launch agent
			launchctl load "$4"
			;;
		update)
			# Unload launch agent
			launchctl unload "$4"
			# Update launch agent plist solar times
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $2" "$4"
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $3" "$4"
			# Load launch agent
			launchctl load "$4"
			;;
	esac
}

# Uninstall
unstl() {
	# Unload launch agents
	launchctl unload "$plistR"
	launchctl unload "$plistS"
	# Check if darkpaper files exist and move to Trash
	if [ -d "$darkdir" ]; then
		if [ -d ~/.Trash/darkmode ]; then
			mv "$darkdir" "$(dirname "$darkdir")"/darkpapere"$(date +%H%M%S)"
			darkdird=$(echo "$(dirname "$darkdir")"/darkpaper*)
			mv "$darkdird" ~/.Trash
		else
			mv "$darkdir" ~/.Trash
		fi
	fi
	if [ -f "$plistR" ] || [ -f "$plistS" ]; then
		mv "$plistR" ~/.Trash
		mv "$plistS" ~/.Trash
	fi
	if [ -f ~/Library/Logs/io.github.peterwooley.darkpaper.log ]; then
		mv ~/Library/Logs/io.github.peterwooley.darkpaper.log ~/.Trash
	fi
	darkpaper off
}

# Error logging
log() {
	while IFS='' read -r line; do
		echo "$(date +"%D %T") $line" >> ~/Library/Logs/io.github.peterwooley.darkpaper.log
	done
}

## Config ##

# Error log
exec 2> >(log)

# Uninstall switch
if [ "$1" == '/u' ]; then # Shell parameter
	unstl
	error=$? # Get exit code from unstl()
	if [ $error -ne 0 ]; then # If exit code not equal to 0
		echo "Uninstall failed! For manual uninstall steps visit https://github.com/peterwooley/darkpaper/issues/1"
		read -rp "Open link in your browser? [y/n] " prompt
		if [[ $prompt =~ [yY](es)* ]]; then
			open https://github.com//darkpaper/issues/1
		fi
		exit $error
	fi
	exit 0
fi

# Create darkpaper directory if doesn't exist
if [ ! -d "$darkdir" ]; then
	mkdir "$darkdir"
	solar
fi

# Deploy launch agents if don't exist
if [ ! -f "$plistR" ] || [ ! -f "$plistS" ]; then
	launch
fi

# Get sunrise and sunset hrs and mins. Strip leading 0 with sed.
riseH=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "" | head -c2 | sed 's/^0//')
riseM=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "" | tail -c3 | sed 's/^0//')
setH=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "" | head -c2 | sed 's/^0//')
setM=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "" | tail -c3 | sed 's/^0//')

# Current 24H time hr and min
timeH=$(date +"%H" | sed 's/^0//')
timeM=$(date +"%M" | sed 's/^0//')

## Code ##

# Solar conditions
if [[ "$timeH" -ge "$riseH" && "$timeH" -lt "$setH" ]]; then
	# Sunrise
	if [[ "$timeH" -ge $((riseH+1)) || "$timeM" -ge "$riseM" ]]; then
		darkpaper off
	# Sunset	
	elif [[ "$timeH" -ge "$setH" && "$timeM" -ge "$setM" ]] || [[ "$timeH" -le "$riseH" && "$timeM" -lt "$riseM" ]]; then 
		darkpaper on
	fi
# Sunset		
elif [[ "$timeH" -ge 0 && "$timeH" -lt "$riseH" ]]; then
	darkpaper on
# Sunrise	
elif [[ "$timeH" -eq "$setH" && "$timeM" -lt "$setM" ]]; then
	darkpaper off
# Sunset	
else
	darkpaper on
fi
