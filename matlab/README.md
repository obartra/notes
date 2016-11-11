# Porting Matlab scripts to JavaScript

A few months ago, I talked about [using SSIM](https://github.com/obartra/notes/tree/master/imageOptimization) to programmatically determine optimal image compression. This was a convenient solution for reducing file size using [ImageMagick](https://www.imagemagick.org) but it was not native. We had to call a shell script that would then call ImageMagick and finally get the SSIM value.

So I looked for JS SSIM packages on npm. There are several ones available but they don't have tests and their results don't match the original [paper](https://ece.uwaterloo.ca/~z70wang/publications/ssim.html) 😱. This led me to implement [ssim.js](https://github.com/obartra/ssim) as a native, fully tested, exact reproduction of the Wang et al. 2004 results.

I wanted to take this opportunity to talk about the different challanges of porting the published [Matlab script](https://ece.uwaterloo.ca/~z70wang/research/ssim/ssim_index.m) to JavaScript.

If you are not familiar with [Matlab](https://en.wikipedia.org/wiki/MATLAB), it's a numerical computing programming language frequently used in research. It makes it easy to operate on arrays and matrices and has many built-in methods useful for data analysis.

For instance, if were to define two 2x3 matrices and a number in Matlab we would type:

```matlab
A = [1 2; 3 4; 5 6]
B = [7 8; 9 0; 1 2]
C = 2
```

This is similar to JS, that could look like:

```javascript
const A = [[1, 2], [3, 4], [5, 6]];
const B = [[7, 8], [9, 0], [1, 2]];
const C = 2;
```

But where Matlab really shines is operating on these values. Adding A, B and C is as easy as:

```matlab
D = A + B + C
```

Matlab is not the only language where scalar operations are also applied to matrices but in JS we have to do this by hand. With our prior matrix definitions we could do:

```javascript
// add two matrices together, cell-by-cell
function addMatrices(mx1, mx2) {
	return mx1.map((row, y) => row.map((cell, x) => cell + mx2[y][x]));
}

// add a scalar value to each cell value
function addScalar(mx, scalar) {
	return mx.map(row => row.map(cell => cell + scalar));
}

// adds two values together regardless of their type
function addTwo(val1, val2) {
	const is1Scalar = typeof val1 === 'number';
	const is2Scalar = typeof val2 === 'number';

	if (is1Scalar && is2Scalar) {
		return val1 + val2;
	} else if (!is1Scalar && !is2Scalar) {
		return addMatrices(val1, val2);
	} else if (is1Scalar) {
		return addScalar(val2, val1);
	} // val2 is a scalar
	return addScalar(val1, val2);
}

// adds n values together regardless of their type
function add(...args) {
	return args.reduce((acc, curr) => addTwo(acc, curr), 0);
}

// Now we can add A, B and C
const D = add(A, B, C);

```

Which in both cases results in the following `D` matrix:

```shell
| 10 | 12 |
|----|----|
| 14 |  6 |
|----|----|
|  8 | 10 |
```

## Storing Matrices in JS

Arguably the most important part when porting Matlab code to JS is to choose the right way to represent matrices. Odds are we'll be accessing each item on each cell many times so the performance of these actions will likely dictate the overall performance of the application.

I know because the first iteration of `ssim.js` was in the slowest possible implementation: nested arrays 🤦.

### Nested Arrays

The main advantage of nested arrays is simplicity. `x` and `y` clearly indicate row and column numbers but that also means that for each item we need to find two elements: first the row array and then the cell.

```javascript
const x = 1;
const y = 1;
const A = [
	[1, 2, 3],
	[4, 5, 6]
];

console.log(A[x][y]);
```

Performance differences between `A[x][y]` and `A[x]` are negligble for small arrays but become significant at scale.

### Single Array

Creating a single array to define a matrix requires us to define some conventions, we can pick any as far as we stay consistent. We'll need to specify matrix dimensions and data ordering. Conventionally, the [sorting](https://en.wikipedia.org/wiki/Row-major_order) for 2-dimensional data will be row or column major. For instance, looking at the previous matrix:

```shell
| 10 | 12 |
|----|----|
| 14 |  6 |
|----|----|
|  8 | 10 |
```

We could store it as `[10, 12, 14, 6, 8, 10]` or `[10, 14, 8, 12, 6, 10]`. Ultimately we'll end up with something like:

```javascript
const A = {
	width: 2,
	height: 3,
	data: [
		10, 12,
		14, 6,
		8, 10
	]
};
```

And we can retrieve with:

```javascript
const x = 1;
const y = 1;

console.log(A.data[x * width + y]);
```

If we are feeling fancy we can add getters and setters:

```javascript
const A = {
	width: 3,
	height: 2,
	get(x, y): {
		return A.data[x * width + y];
	},
	set(x, y, val): {
		A.data[x * width + y] = val;
	},
	data: [1, 2, 3, 4, 5, 6]
};
```

And now we can just do:

```javascript
const x = 1;
const y = 1;

console.log(A.get(x, y));
```

This approach is similar to what [ndarray](https://github.com/scijs/ndarray) does and it's a convenient way to work with n-dimensional data.

### Typed Arrays

Another potential enhancement from here would be to use [TypedArray](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray). [TypedArray support](http://caniuse.com/#feat=typedarrays) is great, but it is worse than just using `[]`, which would work everywhere.

There are additional complications to using TypedArrays like the fact that in Safari 6 and below they are [~10x slower](https://bugs.webkit.org/show_bug.cgi?id=70687) than normal arrays.

Another reason to stick to normal arrays is that modern JS engines will automatically convert `[]` to a TypedArray when possible. When that occurs performance gains are null.

## Memory Allocation

Another way to boost performance, particularly for large arrays, is to define their length ahead of time. Let's look at a potential implementation of matlab's [ones](https://www.mathworks.com/help/matlab/ref/ones.html) method, that generates a matrix with all values set to `1`.

```javascript
function ones(height, width = height) {
	const length = width * height;
	const data = new Array(length);

	for (let i = 0; i < length; i++) {
		data[i] = 1;
	}

	return { data, width, height };
}
```

We can change the third line from `const data = new Array(length);` to `const data = [];` and assess performance, something like:

```javascript
const start = new Date();
const iterations = 100;

for (let i = 0; i < iterations; i++) {
	ones(1000);
}
const duration = new Date().getTime() - start.getTime();

console.log('duration', duration);
```

Preallocating memory for the array *triples* performance for that example (on Node v7.1). That's because our JS engine won't need to perform memory allocation or copy more than once. Andy Sinur's [post](https://gamealchemist.wordpress.com/2013/05/01/lets-get-those-javascript-arrays-to-work-fast/) illustrates this issue clearly:

![](https://gamealchemist.files.wordpress.com/2013/05/array.png)

For that same reason, if the array size is unknown, it's best to create one that's larger than needed and trim it afterwards.

## Built-in Matlab Methods

Matlab was initially released in 1984 so they've had some time to work out bugs and boost performance. It's really a great product but it comes with a price tag of [$2,150 for an individual license](https://web.archive.org/web/20160506213641/http://www.mathworks.com/pricing-licensing/). Even if you are willing to pay for it you can't access the built-in methods implementation, you can only use them. So it doesn't help us to port code.

To do that we can look at open source alternatives like [Octave](https://www.gnu.org/software/octave/) which is free, mostly Matlab-compatible and open source. Unfortunately these alternatives are often less optimized.

A perfect example is the 2D convolution. While Matlab may try to [apply SVD](http://blogs.mathworks.com/steve/2006/11/28/separable-convolution-part-2/) to see if we can do 2 1D convolutions instead, Octave will often perform [the operation](https://searchcode.com/codesearch/view/9581968/) directly. In this case, that check alone allows us to improve performance from O(N^2) to O(2N).

To safely port `conv2` (or any other built-in method) and improve their performance we can mimic Octave's implementation first and once tests are in place, iteratively measure and refactor.

## Built-in JS Methods

Other potential bottlenecks are `[].forEach` and `[].map`. Their performance doesn't matter for the vast majority of cases and they often help write clearer, cleaner, more concise code, which is great. But, for the specific case where repeatedly manipulate hundreds or thousands of items, a [simple loop](http://jsben.ch/#/jAoOH) is the fastest option.

If you really want to use `map` and `forEach`, [lodash](lodash.com) is a great alternative. It would allow you to use `_.each` and `_.map` with much better performance than native methods.
