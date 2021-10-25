/* eslint-env node */

const path = require("path")
const sharedConfig = require("../../../Helpers/Utils/Web/webpack.config")

function config(name, mode = "production") {
  console.log(`Building Navigation for ${mode}`)
  return {
    ...sharedConfig(name, mode),
    entry: {
      index: {
        import: "./Navigation.js"
      }
    },
    output: {
      filename: "navigation_prod.js",
      path: path.resolve(__dirname, ".")
    }
  }
}

module.exports = (env, argv) => {
  const mode = argv.mode || "production"
  return config(mode)
}
