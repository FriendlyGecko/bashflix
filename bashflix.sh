#!/usr/bin/env bash
echo -n "
██████╗  █████╗ ███████╗██╗  ██╗███████╗██╗     ██╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██║     ██║╚██╗██╔╝
██████╔╝███████║███████╗███████║█████╗  ██║     ██║ ╚███╔╝ 
██╔══██╗██╔══██║╚════██║██╔══██║██╔══╝  ██║     ██║ ██╔██╗ 
██████╔╝██║  ██║███████║██║  ██║██║     ███████╗██║██╔╝ ██╗
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝╚═╝  ╚═╝                                    
"

# Sets first argument as $query and creates variables select and resource.
query="$1"
select=0
resource=" "

# Help Documentation
if [ -z "$1" ] || [ "$query" == "-h" ]; then
  echo "Bash script to watch movies and TV shows on Mac OS X and Linux, with subtitles, instantaneously. Just give the name, quickly grab your popcorn and have fun!"
  echo
  echo "Syntax: bashflix [OPTION] \"search query\" subtitles_language"
  echo "options:"
  echo "-u     Update bashflix"
  echo "-s     Select seed from results"
  echo "-p     Previously watched"
  echo "-h     Help"
  echo
  echo "Examples:"
  echo "bashflix \"some movie title 1080p\""
  echo "bashflix \"some serie title s01e01\" pt"
  echo "bashflix -p"
  echo 
  echo "Tips:"
  echo "* Stuck? \"ctrl+c\" and change the search query;"
  echo "* Want to pick a different result? Then use -s;"
  echo "* Subtitles not synced? Use \"j\" to speed it up or \"h\" to delay it;"
  echo "* Stopping? \"space\" to PAUSE, wait a few minutes and \"space\" to PLAY;"
  echo "* What did I watch? \"bashflix -p\" to see which episode to watch next;"
  echo "* Need help? \"bashflix -h\" shows how to use it;"
  echo "* From time to time, use \"bashflix -u\" to update bashflix."
  exit 0

fi

# Checks if user wishes to select seed and sets variable
if [ "$query" == "-s" ]; then
  select=1
  shift
  query="$1"
fi

# Checks if users wishes to update and does so
if [ "$query" == "-u" ]; then
  $(bash <(curl -fsSL https://raw.githubusercontent.com/0zz4r/bashflix/master/install.sh))
  echo "Updated!"
  exit 0
fi

# Checks users bashflix history
if [ "$query" == "-p" ]; then
  echo "Previously watched:"
  echo "$(cat $HOME/.bashflix_history)"
  exit 0
else
  echo "$query" | cat - $HOME/.bashflix_history > temp && mv temp $HOME/.bashflix_history
fi

# Formats query into script readable format
query="${query#\ }"
query="${query%\ }"
query="${query// /.}"

echo "Searching the best torrent..."

# Iterates each plugin in ordered fashion
for file in $HOME/.local/share/bashflix/*; do
  . "$file"

  if [ -z $magnet ]; then
    continue
  else
    echo "Torrent found on $resource: ${magnet}"
    break
  fi
done

# If still no result after iterating through all plugins then prompt user
if [ -z $magnet ]; then
  echo "Could not find torrent for the query ${query}. Change the query."
  exit 1
fi

# Searches for subtitles if argument exists
language=${2}
subtitle=""
if [ -n "${language}" ]; then
  echo "Searching the best subtitles..."
  torrent_name_param=$(awk -F "&" '{print $2}' <<< "$magnet")
  torrent_name_dirty=$(awk -F "=" '{print $2}' <<< "$torrent_name_param")
  torrent_name_raw=$(echo "$torrent_name_dirty" | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g')
  torrent_name_escaped=$(echo -e "$torrent_name_raw")
  torrent_name=$(echo -e "$torrent_name_escaped")
  mkdir -p "/tmp/bashflix/${query}"
  languages=("${language}")
  languages+=("en")
  for language in ${languages[@]}; do
    subliminal download -l "$language" -d "/tmp/bashflix/${query}" "${torrent_name}"
    find /tmp/bashflix/${query} -maxdepth 1 -name "*${language}*.srt" | head -1 | xargs -I '{}' mv {} "/tmp/bashflix/${query}/${query}.${language}.srt"
    subtitle=$(find /tmp/bashflix/${query} -maxdepth 1 -name "${query}.${language}.srt" | head -1)
    if [ -n "$subtitle" ]; then
      echo "Found subtitle for language ${language}"
      #subtitle=$(find /tmp/bashflix/${query} -maxdepth 1 -name "${query}.${language}.srt" | head -1)
      #echo $subtitle
      break;
    fi
  done
fi
echo "Streaming ${torrent_name} with ${subtitle}..."
if [ -n "${subtitle}" ]; then
  peerflix ${magnet} --subtitles ${subtitle} --vlc -- --fullscreen 
else
  peerflix ${magnet} --vlc -- --fullscreen
fi
#if [ -n "${subtitle}" ]; then
#  webtorrent download ${magnet} --mpv -t ${subtitle}
#else
#  webtorrent download ${magnet} --mpv
#fi
trap "rm -rf /tmp/torrent-stream/*" exit 0
