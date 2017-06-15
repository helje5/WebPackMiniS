// multiply.js
var multiply = function (a, b) {
  var total = 0;
  for (var i = 0; i < b; i++) {
    total = sum(a, total);
  }
  return total;
};
