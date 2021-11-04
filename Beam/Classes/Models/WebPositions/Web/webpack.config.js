/* eslint-env node */

const path = require("path")
const webpack = require("webpack")
const sharedConfig = require("../../../Helpers/Utils/Web/webpack.config")

function config(name, mode = "production") {
  console.log(`Building WebPositions for ${mode}`)
  return {
    ...sharedConfig(name, mode),
    entry: {
      index: {
        import: "./WebPositions.js"
      }
    },
    output: {
      filename: "WebPositions_prod.js",
      path: path.resolve(__dirname, ".")
    }
  }
}

module.exports = (env, argv) => {
  const mode = argv.mode || "production"
  return config(mode)
}
