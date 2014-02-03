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
watcher.on('create', function (filename, stats) {
  console.log('Added %s: %s', stats.isDir ? 'dir' : 'file', filename);
});
```


## API

### `Inotifyr(dir[, options])`

#### Options

An object with the following properties

* `events`: (String | Array) *Default:* `['create', 'modify', 'delete', 'move']`
   A list of the events below to watch for.
* `recursive`: (Boolean) *Default:* `false`
  Should sub directories be watched?

### Available Events

* `access`:
* `attrib`:
* `close_write`:
* `close_nowrite`:
* `create`:
* `delete`:
* `delete_self`:
* `modify`:
* `move_self`:
* `move_from`:
* `move_to`:
* `open`:
* `all`:
* `close`:
* `move`:

## Development

Executing the tests

```bash
$ npm test
```
