/* eslint-env node */

const path = require("path")
const webpack = require("webpack")
const sharedConfig = require("../../../Helpers/Utils/Web/webpack.config")

function config(mode = "production") {
  console.log(`Building Point and Shoot for ${mode}`)
  return {
    ...sharedConfig(mode),
    entry: {
      index: {
        import: "./index_native.js"
      }
    },
    output: {
      filename: "pns_prod.js",
      path: path.resolve(__dirname, ".")
    },
    plugins: [
      new webpack.DefinePlugin({
        "process.env.PNS_STATUS": process.env.PNS_STATUS === "1"
      })
    ]
  }
}

module.exports = (env, argv) => {
  const mode = argv.mode || "production"
  return config(mode)
}
