// index.js - our application logic
// https://www.ag-grid.com/ag-grid-understanding-webpack/

import multiply from './multiply';
import sum      from './sum';

var totalMultiply = multiply(5, 3);
var totalSum = sum(5, 3);

console.log('Product of 5 and 3 = ' + totalMultiply);
console.log('Sum of 5 and 3 = ' + totalSum);

// import the CSS we want to use here
import './math_output.css';

// create the body
const body = document.createElement("body");
document.documentElement.appendChild(body);

// calculate the product and add it to a span
const multiplyResultsSpan = document.createElement('span');
multiplyResultsSpan.appendChild(
  document.createTextNode(`Product of 5 and 3 = ${totalMultiply}`));

// calculate the sum and add it to a span
const sumResultSpan = document.createElement('span');
sumResultSpan.appendChild(
  document.createTextNode(`Sum of 5 and 3 = ${totalSum}`));

// add the results to the page
document.body.appendChild(multiplyResultsSpan);
document.body.appendChild(sumResultSpan);

