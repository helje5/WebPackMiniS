// we don't actually read this, yet.
var path = require('path');

module.exports = {
  entry:  './src/index.js',
  output: {
    path: path.resolve(__dirname, './dist/'),
    filename: 'bundle.js'
  }
}
