/* eslint-env node */

const path = require("path")

function config(name, mode = "production") {
  return {
    mode,
    devtool: mode === "production" ? undefined : "inline-source-map",
    devServer: {
      contentBase: "./dist",
      https: false, // Required by service workers if we don't use localhost
      public: "front.lvh.me:8080",
      host: "0.0.0.0",
      allowedHosts: [".lvh.me"]
    },
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          use: "ts-loader",
          exclude: /node_modules/
        },
        {
          test: [/\.js$/],
          enforce: "pre",
          exclude: /node_modules/,
          use: ["source-map-loader"]
        },
        {
          test: /\.scss$/,
          use: [
            "style-loader", // Creates `style` nodes from JS strings
            "css-loader", // Translates CSS into CommonJS
            "sass-loader" // Compiles Sass to CSS
          ],
          exclude: /node_modules/
        },
        {
          test: /\.svg$/i,
          type: "asset/resource"
        }
      ]
    },
    resolve: {
      extensions: [".tsx", ".ts", ".js"],
      modules: [path.resolve("./node_modules"), path.resolve("./src")]
    }
  }
}

module.exports = (env, argv) => {
  const mode = env || argv.mode || "production"
  return config(mode)
}
