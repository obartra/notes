const { join } = require('path');
const test = require('blue-tape');
const image = require('../src/image');
const getPixels = require('get-pixels');

const loaded = loadSamples();

function loadSamples() {
	const samples = {
		'3x3': './samples/3x3.jpg',
		lena: './samples/lena.jpg',
		bit1: './samples/bitdepth/1_bit.png',
		bit2: './samples/bitdepth/2_bit.png',
		bit4: './samples/bitdepth/4_bit.png',
		bit8: './samples/bitdepth/8_bit.png',
		bit24: './samples/bitdepth/24_bit.png'
	};

	const promises = Object.keys(samples).map(key =>
		new Promise((resolve, reject) => {
			const path = join(__dirname, samples[key]);

			getPixels(path, (err, pixels) => {
				if (err) {
					reject(err);
				} else {
					resolve({ [key]: pixels });
				}
			});
		})
	);

	return Promise.all(promises).then(values => Object.assign(...values));
}

test('should calculate luminance for RGB (luma)', (t) => {
	const luma = image.luma([100, 200, 50]);

	t.equal(luma, 167.91);
	t.end();
});

test('should return the same value if all pixels are the same (luma)', (t) => {
	const luma = image.luma([200, 200, 200]);

	t.equal(luma, 200);
	t.end();
});

test('should weight each color based on the ITU spec (luma)', (t) => {
	const rLuma = image.luma([1, 0, 0]);
	const gLuma = image.luma([0, 1, 0]);
	const bLuma = image.luma([0, 0, 1]);

	t.equal(rLuma, 0.2126);
	t.equal(gLuma, 0.7152);
	t.equal(bLuma, 0.0722);

	t.end();
});

test('should determine image dimensions (getDimensions)', t => loaded.then((pixels) => {
	const threeByThree = image.getDimensions(pixels['3x3']);
	const lena = image.getDimensions(pixels.lena);
	const leaf = image.getDimensions(pixels.bit1);

	t.equal(threeByThree.width, 3);
	t.equal(threeByThree.height, 3);
	t.equal(lena.width, 512);
	t.equal(lena.height, 512);
	t.equal(leaf.width, 300);
	t.equal(leaf.height, 225);
}));

test('should retrieve bit depth from image (getBitDepth)', t => loaded.then((pixels) => {
	const b1 = image.getBitDepth(pixels.bit1);
	const b2 = image.getBitDepth(pixels.bit2);
	const b4 = image.getBitDepth(pixels.bit4);
	const b8 = image.getBitDepth(pixels.bit8);
	const b24 = image.getBitDepth(pixels.bit24);

	t.equal(b1, 1);
	t.equal(b2, 2);
	t.equal(b4, 4);
	t.equal(b8, 8);
	t.equal(b24, 24);
}));
