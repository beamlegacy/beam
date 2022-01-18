/* eslint-env node */

const path = require("path")
const sharedConfig = require("../../../Helpers/Utils/Web/webpack.config")
const TerserPlugin = require("terser-webpack-plugin");

function config(name, mode) {
  console.log(`Building ${name} for ${mode}`)
  return {
    ...sharedConfig(name, mode, { TerserPlugin }),
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

module.exports = () => {
  const isDebugOrTest = process.env.ENV == "debug" || process.env.ENV == "test"
  if (isDebugOrTest) {
    return config("Navigation", "development")
  } else {
    return config("Navigation", "production")
  }
}
