'use strict';

var sysPath = require('path'),
	setup = require('umd-builder/setup'),
	projectRoot = sysPath.resolve(__dirname, '..');

setup(projectRoot, function(err) {
	if (err) {
		console.error(err);
	}
});