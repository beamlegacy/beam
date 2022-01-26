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
        import: "./PasswordManager.js"
      }
    },
    output: {
      filename: "PasswordManager_prod.js",
      path: path.resolve(__dirname, ".")
    }
  }
}

module.exports = (env, argv) => {
  const isDebugOrTest = process.env.ENV == "debug" || process.env.ENV == "test"
  if (isDebugOrTest) {
    return config("PasswordManager", "development")
  } else {
    return config("PasswordManager", "production")
  }
}
