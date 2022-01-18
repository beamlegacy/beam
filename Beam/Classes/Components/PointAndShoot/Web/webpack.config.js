/* eslint-env node */

const path = require("path")
const webpack = require("webpack")
const sharedConfig = require("../../../Helpers/Utils/Web/webpack.config")
const TerserPlugin = require("terser-webpack-plugin");

function config(name, mode) {
  console.log(`Building ${name} for ${mode}`)
  return {
    ...sharedConfig(name, mode, { TerserPlugin }),
    entry: {
      index: {
        import: "./index_native.js"
      }
    },
    output: {
      filename: "pns_prod.js",
      path: path.resolve(__dirname, ".")
    }
  }
}

module.exports = () => {
  const isDebugOrTest = process.env.ENV == "debug" || process.env.ENV == "test"
  if (isDebugOrTest) {
    return config("Point and Shoot", "development")
  } else {
    return config("Point and Shoot", "production")
  }
}
