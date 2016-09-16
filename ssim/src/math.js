function average(xn) {
	return sum(xn) / xn.length;
}

function variance(xn) {
	const x̄ = average(xn);
	const sqDiff = xn
		.map(diffFn(x̄))
		.map(diff => Math.pow(diff, 2));

	return average(sqDiff);
}

function covariance(xn, yn) {
	const x̄ = average(xn);
	const ȳ = average(yn);

	const diffxn = xn.map(diffFn(x̄));
	const diffny = yn.map(diffFn(ȳ));
	const power = diffxn.map((diffx, index) => diffx * diffny[index]);

	return average(power);
}

function sum(xn) {
	return xn.reduce((accumulated, current) => accumulated + current);
}

function diffFn(x̄) {
	return x => x - x̄;
}

module.exports = {
	average,
	variance,
	covariance
};
