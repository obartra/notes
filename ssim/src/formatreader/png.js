const ndarray = require('ndarray');
const { PNG } = require('pngjs');

module.exports = function handlePNG(data) {
	const png = new PNG();

	return new Promise((resolve, reject) => {
		let bitDepth;

		png
		.on('metadata', ({ depth }) => { bitDepth = depth; })
		.parse(data, (err, imgData) => {
			if (err) {
				reject(err);
			}

			const pixels = ndarray(
				new Uint8Array(imgData.data), [
					imgData.width | 0,
					imgData.height|0, 4],
					[4, 4 * imgData.width | 0, 1
				], 0);

			pixels.bitDepth = bitDepth;
			resolve(pixels);
		});
	});
};
