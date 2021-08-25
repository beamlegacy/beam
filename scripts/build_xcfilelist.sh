#!/bin/sh
# Creates a `.xcfilelist` file for the "Build Web" build step.

# Clear file
> ./WebFileList.xcfilelist

# Add all ts and scss component files to xcfilelist
for extension in ts scss
do
  find ./Beam/Classes/Components -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList.xcfilelist
done

# Print the list of watched files
cat ./WebFileList.xcfilelist
