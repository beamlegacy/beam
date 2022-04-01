/* eslint-env node */

const path = require("path")
const webpack = require("webpack")
const TerserPlugin = require("terser-webpack-plugin")
const PnpWebpackPlugin = require(`pnp-webpack-plugin`);

function config(name, mode) {
  return {
    cache: {
      type: 'filesystem',
      cacheDirectory: path.resolve(__dirname, '.temp_cache'),
    },
    mode,
    name,
    entry: "./src/index.js",
    output: {
      filename: `${name}_prod.js`,
      path: path.resolve(__dirname, "./dist")
    },
    devtool: Boolean(mode != "development") ? undefined : "inline-source-map",
    module: {
      rules: [
        {
          test: /\.ts$/,
          loader: require.resolve('ts-loader'),
          options: PnpWebpackPlugin.tsLoaderOptions(),
        },
        {
          test: [/\.js$/],
          use: [
            require.resolve('source-map-loader'),
          ]
        },
        {
          test: /\.(sa|sc|c)ss$/i,
          use: [
            require.resolve('style-loader'), // Creates `style` nodes from JS strings
            require.resolve('css-loader'), // Translates CSS into CommonJS
            require.resolve('sass-loader'), // Compiles Sass to CSS
          ],
          exclude: /node_modules/
        },
        {
          test: /\.svg$/i,
          type: "asset/resource"
        }
      ]
    },
    optimization: {
      minimize: Boolean(mode != "development"),
      minimizer: [
        new TerserPlugin({
          terserOptions: {
            compress: {
              drop_console: true
            },
            format: {
              comments: false
            }
          },
          extractComments: false
        })
      ]
    },
    resolve: {
      extensions: [".tsx", ".ts", ".js"],
      plugins: [
        PnpWebpackPlugin,
      ],
    },
    resolveLoader: {
      plugins: [
        PnpWebpackPlugin.moduleLoader(module),
      ],
    },
  }
}

module.exports = (env, _argv, modules) => {
  const isDebugOrTest = process.env.ENV == "debug" || process.env.ENV == "test"
  if (isDebugOrTest) {
    return config("PointAndShoot", "development", modules)
  } else {
    return config("PointAndShoot", "production", modules)
  }
}
