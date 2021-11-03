#!/bin/sh
# Creates a `.xcfilelist` file for the "Build Web" build step.

# Clear file
> ./WebFileList_webpositions.xcfilelist

# Add all ts and scss component files to xcfilelist
for extension in ts scss
do
  find ./Beam/Classes/Models/WebPositions/Web -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList_webpositions.xcfilelist
  find ./Beam/Classes/Helpers/Utils/Web -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList_webpositions.xcfilelist
done

# Print the list of watched files
cat ./WebFileList_webpositions.xcfilelist
