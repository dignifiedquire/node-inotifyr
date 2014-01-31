# node-inotifyr

> Because file watching is hard.


[![Build Status](https://travis-ci.org/Dignifiedquire/node-inotifyr.png?branch=master)](https://travis-ci.org/Dignifiedquire/node-inotifyr)

## Installation

```bash
$ npm install inotifyr
```

## Usage

```js
var Inotifyr = require('inotifyr');

var watcher = new Inotifyr('path/to/watch');
watcher.on('add', function (filename, stats) {
  console.log('Added %s: %s', stats.isDir ? 'dir' : 'file', filename);
});
```


## API

### `Inotifyr(dir[, options])`

#### Options

### Available Events

* `add`

## Development

Executing the tests

```bash
$ npm test
```
