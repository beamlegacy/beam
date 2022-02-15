#!/bin/sh
# Creates a `.xcfilelist` file for the "Build Web" build step.

# Clear file
> ./WebFileList_passwordmanager.xcfilelist

# Add all ts and scss component files to xcfilelist
for extension in ts scss
do
  find ./Beam/Classes/Components/Password/Web -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList_passwordmanager.xcfilelist
  find ./Beam/Classes/Helpers/Utils/Web -path "**/node_modules" -prune -false -o -name "*.$extension" >> ./WebFileList_passwordmanager.xcfilelist
done

# Print the list of watched files
cat ./WebFileList_passwordmanager.xcfilelist
