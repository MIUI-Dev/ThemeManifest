#!/bin/bash
tmpDir=tmp
xmlFile=$tmpDir/description.xml
themeFileName=$(basename $1)
zipFileSize=$(du -h previews/swg-v1.2.zip | cut -f 1)

# Delete existing temp files
rm -rf $tmpDir

# Extract the description.xml to /tmp
unzip -q $1 description.xml -d $tmpDir/

# Make the XML file globally readable
chmod -R a+r $tmpDir

# Function to parse the XML file
#
# This will create 3 variables from the Theme XML file:
#
# $title: Theme name
# $author: Theme author
# $version: Theme version
function parseXML() {
  elemList=( $(cat $xmlFile | tr '\n' ' ' | XMLLINT_INDENT="" xmllint --format - | grep -e "</.*>$" | while read line; do \
    echo $line | sed -e 's/^.*<\///' | cut -d '>' -f 1; \
  done) )

  totalNoOfTags=${#elemList[@]}; ((totalNoOfTags--))
  suffix=$(echo ${elemList[$totalNoOfTags]} | tr -d '</>')
  suffix="${suffix}_"

  for (( i = 0 ; i < ${#elemList[@]} ; i++ )); do
    elem=${elemList[$i]}
    elemLine=$(cat $xmlFile | tr '\n' ' ' | XMLLINT_INDENT="" xmllint --format - | grep "</$elem>")
    echo $elemLine | grep -e "^</[^ ]*>$" 1>/dev/null 2>&1
    if [ "0" = "$?" ]; then
      continue
    fi
    elemVal=$(echo $elemLine | tr '\011' '\040'| sed -e 's/^[ ]*//' -e 's/^<.*>\([^<].*\)<.*>$/\1/' | sed -e 's/^[ ]*//' | sed -e 's/[ ]*$//')
    xmlElem="$(echo $elem | sed 's/-/_/g')"
    eval ${xmlElem}=`echo -ne \""${elemVal}"\"`
    attrList=($(cat $xmlFile | tr '\n' ' ' | XMLLINT_INDENT="" xmllint --format - | grep "</$elem>" | tr '\011' '\040' | sed -e 's/^[ ]*//' | cut -d '>' -f 1  | sed -e 's/^<[^ ]*//' | tr "'" '"' | tr '"' '\n'  | tr '=' '\n' | sed -e 's/^[ ]*//' | sed '/^$/d' | tr '\011' '\040' | tr ' ' '>'))
    for (( j = 0 ; j < ${#attrList[@]} ; j++ )); do
      attr=${attrList[$j]}
      ((j++))
      attrVal=$(echo ${attrList[$j]} | tr '>' ' ')
      attrName=`echo -ne ${xmlElem}_${attr}`
      eval ${attrName}=`echo -ne \""${attrVal}"\"`
    done
  done
}

# Parse the XML file
parseXML

safeThemeName=$(echo $title|sed 's/ /_/g')

# Unzip the preview images to a temp folder
unzip -q -j $1 preview/* -d $tmpDir/$safeThemeName/

# Remove all non image files
find tmp/SWG -type f \! \( -name "*.jpg" -or -name "*.png" \) -delete

# Make the images globally readable/writable
chmod -R a+r $tmpDir

# Create the theme preview folder
mkdir -p previews/$safeThemeName

# Convert the images
convert $tmpDir/$safeThemeName/0.*[x167] previews/$safeThemeName/$safeThemeName\_thumbnail.jpg
convert $tmpDir/$safeThemeName/*[x333] previews/$safeThemeName/%d.jpg

# Check the files into git
git add previews/$safeThemeName
git commit

# Print the manifest lines
echo "
Add the following code to the proper manifest file:

  {
    \"theme_name\": \"$title\",
    \"theme_url\": \"http://magicmonkeystudios.com/android/n_i_x/themes/$themeFileName\",
    \"theme_author\": \"$author\","
echo -n "    \"theme_preview_url\": \"http://themes.miui-themes.com/previews/$safeThemeName/$safeThemeName"
echo "_thumbnail.jpg\",
    \"theme_size\": \"$zipFileSize\",
    \"theme_version\": \"$version\",
    \"theme_screenshot_urls\": ["

find previews/$safeThemeName -type f \! -name "*thumbnail.*" -exec echo "                              \"http://themes.miui-themes.com/{}\"," \;

echo "                             ]
  },

"