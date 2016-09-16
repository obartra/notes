const fs = require('fs');
const request = require('request');
const mime = require('mime-types');

const handlePNG = require('./formatreader/png');
const handleJPEG = require('./formatreader/jpg');
const handleGIF = require('./formatreader/gif');

function doParse(mimeType, data) {
	switch (mimeType) {
	case 'image/png':
		return handlePNG(data);
	case 'image/jpg':
	case 'image/jpeg':
		return handleJPEG(data);
	case 'image/gif':
		return handleGIF(data);
	default:
		return Promise.reject(new Error(`Unsupported file type: ${mimeType}`));
	}
}

function loadBuffer(url, type) {
	if (!type) {
		return Promise.reject(new Error('Invalid file type'));
	}
	return doParse(type, url);
}

function loadUrl(url, type) {
	return new Promise((resolve, reject) => {
		request({ url, encoding: null }, (err, response, body) => {
			if (err) {
				return reject(err);
			} else if (!type) {
				if (response.getHeader !== undefined) {
					type = response.getHeader('content-type');
				} else if (response.headers !== undefined) {
					type = response.headers['content-type'];
				}
			}

			if (!type) {
				return reject(new Error('Invalid content-type'));
			}

			return doParse(type, body).then(resolve).catch(reject);
		});
	});
}

function loadFs(path, type) {
	return new Promise((resolve, reject) => {
		fs.readFile(path, (err, data) => {
			if (err) {
				return reject(err);
			}

			type = type || mime.lookup(path);

			if (!type) {
				return reject(new Error('Invalid file type'));
			}
			return doParse(type, data).then(resolve).catch(reject);
		});
	});
}

module.exports = function loader(url, type) {
	if (Buffer.isBuffer(url)) {
		return loadBuffer(url, type);
	} else if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
		return loadUrl(url, type);
	}
	return loadFs(url, type);
};
