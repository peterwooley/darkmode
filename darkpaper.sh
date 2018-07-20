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
        tell current desktop
          set picture to "~/Pictures/sunrise-wallpaper.jpg"
        end tell
      end tell
			'

      if [ -f "$plistR" ] || [ -f "$plistS" ]; then # Prevent uninstaller from continuing
				# Get sunset launch agent start interval time
				plistSH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistS" 2> /dev/null)
				plistSM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistS" 2> /dev/null)
				if [ -z "$plistSH" ] && [ -z "$plistSM" ]; then # If plist solar time vars are empty
					editPlist add "$setH" "$setM" "$plistS" # Run add solar time plist function
				elif [[ "$plistSH" -ne "$setH" ]] || [[ "$plistSM" -ne "$setM" ]]; then # If launch agent times and solar times differ
					editPlist update "$setH" "$setM" "$plistS" # Run update solar time plist function
				fi
				# Run solar query on first day of week
				if [ "$(date +%u)" = 1 ]; then
					solar
				fi
			fi
			;;
		on)
			# Set sunset wallpaper
			osascript -e '
      tell application "System Events"
        tell current desktop
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
	# Set location
	# Get city and nation from http://ipinfo.io
	loc=$(curl -s ipinfo.io/geo | awk -F: '{print $2}' | awk 'FNR ==3 {print}' | sed 's/[", ]//g')
	nat=$(curl -s ipinfo.io/geo | awk -F: '{print $2}' | awk 'FNR ==5 {print}' | sed 's/[", ]//g')
	# Get solar times
	riseT=$(curl -s "https://query.yahooapis.com/v1/public/yql?q=select%20astronomy.sunrise%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22${loc}%2C%20${nat}%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys" | awk -F\" '{print $22}')
	setT=$(curl -s "https://query.yahooapis.com/v1/public/yql?q=select%20astronomy.sunset%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22${loc}%2C%20${nat}%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys" | awk -F\" '{print $22}')
	# Convert times to 24H
	riseT24=$(date -jf "%I:%M %p" "${riseT}" +"%H:%M" 2> /dev/null)
	setT24=$(date -jf "%I:%M %p" "${setT}" +"%H:%M" 2> /dev/null)
	# Store times in database
	sqlite3 "$darkdir"/solar.db <<EOF
	CREATE TABLE IF NOT EXISTS solar (id INTEGER PRIMARY KEY, time VARCHAR(5));
	INSERT OR IGNORE INTO solar (id, time) VALUES (1, '$riseT24'), (2, '$setT24');
	UPDATE solar SET time='$riseT24' WHERE id=1;
	UPDATE solar SET time='$setT24' WHERE id=2;
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
			# Add solar times to launch agent plist
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Hour integer $2" "$4"
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Minute integer $3" "$4"
			# Reload launch agent
			launchctl unload "$4"
			launchctl load "$4"
			;;
		update)
			# Update launch agent plist solar times
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $2" "$4"
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $3" "$4"
			# Reload launch agent
			launchctl unload "$4"
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
		mv "$darkdir" ~/.Trash
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
