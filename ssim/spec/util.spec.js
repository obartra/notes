const test = require('blue-tape');
const util = require('../src/util');

test('should return an array of length n (times)', (t) => {
	const arr = util.times(20);

	t.equal(arr.length, 20);
	t.end();
});

test('should contain the index as value (times)', (t) => {
	const arr = util.times(2);

	arr.forEach((value, index) => t.equal(value, index));
	t.end();
});
