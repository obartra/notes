/* eslint-disable no-console */
const getPixels = require('./src/readpixels');
const window = require('./src/window');

getPixels('./spec/samples/3x3.jpg')
	.then((pixels) => {
		console.log(pixels.shape);
		window.getWindows(pixels);
		// Object.keys(pixels).forEach((prop) => {
		// 	console.log(prop, pixels[prop]);
		// });
	})
	.catch(err => console.error('oh no', err));
