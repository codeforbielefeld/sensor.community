#!/usr/bin/env bash

set -ex

export LC_ALL=C

# download from http://archive.sensor.community
# preferably from http://archive.sensor.community/csv_per_month, as these include the whole month
inputCSV="${1:?You must provide the path to a csv}"
tmpFilePrefix="$(basename $inputCSV)"

function clean() {
  find . -maxdepth 1 -type f -name "$tmpFilePrefix-*" -delete
}
trap clean 0

# split file for parallel processing
split -u -d -n $(nproc) "$inputCSV" "./$tmpFilePrefix-grep-"

# find sensors in area Bielefeld
# the regex matches all ;lat;lon; that are in Bielefeld's bounding box (51.914,8.37,52.115,8.663 (https://wiki.openstreetmap.org/wiki/Bielefeld))
find . -maxdepth 1 -type f -name "$tmpFilePrefix-grep-*" | xargs -t -r -P $(nproc) -i sh -c "grep --line-buffered -P ';5((1\.9(1([4-9]\d*)|([2-9]\d*))|([2-9]\d*))|2\.((1(1(([0-4]\d*)|5))|(0\d*))|(0\d*)));8\.((3((7\d*)|([8-9]\d*)))|([4-5]\d*)|(6((6(3|([0-2]\d*)))|([0-5]\d*))));' '{}' > './{}.csv'"

#merge files
find . -maxdepth 1 -type f -name "$tmpFilePrefix-grep-*.csv" -exec cat {} + > "./$tmpFilePrefix-area.csv"

# filter unique locations for Bielefeld
for entry in $(awk -F ';' '{if (!seen[$4+";"+$5]++) {print $0}}' "./$tmpFilePrefix-area.csv")
do
  lat=$(echo "$entry" | awk -F ';' '{print $4}')
  lon=$(echo "$entry" | awk -F ';' '{print $5}')
  city=$(curl -G --silent --data-urlencode "lat=$lat" --data-urlencode "lon=$lon" --data-urlencode "format=json" --data-urlencode "addressdetails=1" https://nominatim.openstreetmap.org/reverse | jq -r .address.city)
  if [ "$city" = "Bielefeld" ]; then
    rg "$(echo "$entry" | awk -F ';' '{print $1 ".+" $4 ";" $5}')" "./$tmpFilePrefix-area.csv"
  fi
done > "$inputCSV-filtered.csv"

