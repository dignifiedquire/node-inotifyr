# node-inotifyr

> Because file watching is hard.


[![Build Status](https://travis-ci.org/Dignifiedquire/node-inotifyr.png?branch=master)](https://travis-ci.org/Dignifiedquire/node-inotifyr) [![Dependency Status](https://david-dm.org/Dignifiedquire/node-inotifyr.png)](https://david-dm.org/Dignifiedquire/node-inotifyr) [![devDependency Status](https://david-dm.org/Dignifiedquire/node-inotifyr/dev-status.png)](https://david-dm.org/Dignifiedquire/node-inotifyr#info=devDependencies)
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

* `access`: File was accessed (read)
* `attrib`: Metadata changed, e.g., permissions, timestamps, extended attributes,
  link count (since Linux 2.6.25), UID, GID, etc.
* `close_write`: File opened for writing was closed
* `close_nowrite`: File not opened for writing was closed
* `create`: File/directory created in the watched directory
* `delete`: File/directory deleted from the watched directory
* `delete_self`: Watched file/directory was deleted
* `modify`: File was modified
* `move_self`: Watched file/directory was moved
* `move_from`: File moved out of the watched directory
* `move_to`: File moved into watched directory
* `open`: File was opened
* `all`: Watch for all kind of events
* `close`: (`close_write | close_nowrite`) Close
* `move`: (`move_to | move_from) Moves

## Development

Executing the tests

```bash
$ npm test
```

Running jshint

```bash
$ npm run hint
```
