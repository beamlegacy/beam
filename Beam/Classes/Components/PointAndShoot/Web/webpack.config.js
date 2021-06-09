const path = require("path")

const webpack = require("webpack")

function config(mode = "production") {
  console.log("Building for", mode)
  return {
    mode,
    entry: {
      index: {
        import: "./index_native.js",
      },
    },
    devtool: "source-map",
    devServer: {
      contentBase: "./dist",
      https: false, // Required by service workers if we don't use localhost
      public: "front.lvh.me:8080",
      host: "0.0.0.0",
      allowedHosts: [".lvh.me"],
    },
    plugins: [
      new webpack.DefinePlugin({
        "process.env.PNS_STATUS": process.env.PNS_STATUS === "1",
      }),
    ],
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          use: "ts-loader",
          exclude: /node_modules/,
        },
        {
          test: [/\.js$/],
          enforce: "pre",
          exclude: /node_modules/,
          use: ["source-map-loader"],
        },
        {
          test: /\.scss$/,
          use: [
            "style-loader", // Creates `style` nodes from JS strings
            "css-loader", // Translates CSS into CommonJS
            "sass-loader", // Compiles Sass to CSS
          ],
          exclude: /node_modules/,
        },
        {
          test: /\.svg$/i,
          type: "asset/resource",
        },
      ],
    },
    resolve: {
      extensions: [".tsx", ".ts", ".js"],
      modules: [path.resolve("./node_modules"), path.resolve("./src")],
    },
    output: {
      filename: "index_prod.js",
      library: "beam",
      path: path.resolve(__dirname, "."),
    },
  }
}

module.exports = (env, argv) => {
  const mode = argv.mode || "production"
  return config(mode)
}
