const ndarray = require('ndarray');
const jpeg = require('jpeg-js');

module.exports = function handleJPEG(data) {
	return new Promise((resolve, reject) => {
		try {
			const jpegData = jpeg.decode(data);

			if (!jpegData) {
				reject(new Error('Error decoding jpeg'));
			} else {
				const nshape = [jpegData.height, jpegData.width, 4];
				const result = ndarray(jpegData.data, nshape);
				const pixels = result.transpose(1, 0);

				pixels.bitDepth = 0;
				resolve(pixels);
			}
		} catch (e) {
			reject(e);
		}
	});
};
