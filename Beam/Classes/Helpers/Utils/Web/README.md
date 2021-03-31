## Collect Web API
The part of the code aims to collect fragments of from web pages 
and associate them with (possibly annotated) notes.

# Build
Builiding this part of the code consist in
- aggregating several JS files in one
- minifying the JS and CSS code

This is automatically done by the XCode build,
through a build phase that executes `/scripts/build_js.sh`

Should you want to do it manually, run:
```
npm run build
```
to both install dependencies and build the JS code.
