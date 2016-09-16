function times(length) {
	return Array.apply(null, { length }) // eslint-disable-line prefer-spread
		.map((undef, index) => index);
}

module.exports = {
	times
};
