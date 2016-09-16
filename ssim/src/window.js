const { getPixel, getDimensions } = require('./image');
const { times } = require('./util');

function getWindowSize(pixels, windowSize = 8) {
	const imgSize = getDimensions(pixels);

	return Math.min(windowSize, imgSize.width, imgSize.height);
}

function getWindows(pixels, size) {
	size = getWindowSize(pixels, size);

	console.log(size);

	times(size).forEach(width =>
		times(size).forEach(height =>
			console.log(`${width} ${height}`, getPixel(height, width, pixels))
		)
	);
	// return iterator for windows
}

/**
 *  0 0: 157r 191g 203b		0 1: 111r 148g 157b		0 2: 162r 202g 210b
 *  1 0:  71r  65g  65b		1 1: 139r 135g 132b		1 2:  68r  69r  63b
 *  2 0: 176r 144g  95b		2 1: 155r 125g  73b		2 2: 204r 178r 121b
 */

module.exports = {
	getWindows
};
