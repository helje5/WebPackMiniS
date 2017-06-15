// index.js - our application logic
// https://www.ag-grid.com/ag-grid-understanding-webpack/

import multiply from './multiply';
import sum      from './sum';

var totalMultiply = multiply(5, 3);
var totalSum = sum(5, 3);

console.log('Product of 5 and 3 = ' + totalMultiply);
console.log('Sum of 5 and 3 = ' + totalSum);
