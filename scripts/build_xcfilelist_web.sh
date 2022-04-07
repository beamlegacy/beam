#!/bin/sh
# Creates a `.xcfilelist` file for the "Build Web" build input step.
# 1. Clear file
> ./WebFileList_input.xcfilelist

# 2. Add all ts, sccs, css component files to xcfilelist
for extension in ts scss css
do
  find ./Beam -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList_input.xcfilelist
done

# 3. Print the list of watched files
echo "-------- WebFileList_input.xcfilelist files --------"
cat ./WebFileList_input.xcfilelist

# Creates a `.xcfilelist` file for the "Build Web" build input step.
# 1. Clear file
> ./WebFileList_output.xcfilelist

# 2. Add all ts and scss component files to xcfilelist
find ./Beam -path "**/dist/**" -path "**/node_modules" -prune -false -o -name "*_prod.js" >> ./WebFileList_output.xcfilelist

# 3. Print the list of watched files
echo "-------- WebFileList_output.xcfilelist files --------"
cat ./WebFileList_output.xcfilelist

# Updates the yarn-workspaces.json file
yarn workspaces list --json | jq --slurp . > yarn-workspaces.json
echo "-------- yarn workspaces --------"
cat ./yarn-workspaces.json