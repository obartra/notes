const { times } = require('./util');

/**
 * Values derived from http://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.709-6-201506-I!!PDF-E.pdf
 * Page 4, "Derivation of luminance signal"
 */
function luma(subPixels) {
	return (0.2126 * subPixels[0]) + (0.7152 * subPixels[1]) + (0.0722 * subPixels[2]);
}

function getSubPixel(pixels, offset, index) {
	return pixels.data[offset + (pixels.stride[2] * index)];
}

function getPixel(x, y, pixels) {
	const offset = pixels.offset + (pixels.stride[0] * x) + (pixels.stride[1] * y);

	return times(3).map(index => getSubPixel(pixels, offset, index));
}

function getDimensions({ shape }) {
	return {
		width: shape[0],
		height: shape[1],
		channels: shape[2]
	};
}

function getBitDepth(pixels) {
	return pixels.bitDepth;
}

module.exports = {
	luma,
	getPixel,
	getDimensions,
	getBitDepth
};
