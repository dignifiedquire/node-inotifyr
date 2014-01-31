
var inherits = require('util').inherits;
var EventEmitter = require('events').EventEmitter;
var path = require('path');
var fs = require('fs-extended');

var ReadStream = require('read-stream');
var Inotify = require('inotify').Inotify;
var through = require('through2');
var _ = require('lodash');
var async = require('async');

var ERROR = {
    ENOENT: 'ENOENT'
};

function addRecursiveWatches(watcher, dir, events, callback, emitter, missing) {
    // Watch all directories inside dir
    fs.listDirs(dir, function (err, dirs) {
        if (err) {
            if (err.code === ERROR.ENOENT) {
                // If we can't read the directory yet try again a little bit later.
                _.delay(function () {
                    addRecursiveWatches(watcher, dir, events, callback, emitter, true);
                }, 10);
            }
            return;
        }
        if (missing) {
            console.log('missing %s', dir);
            fs.readdir(dir, function (err, files) {
                console.log(files);
                _.forEach(files, function (file) {
                    emitter.emit('add', file);
                });
            });
        }

        async.each(dirs, function (item) {
            item = path.join(dir, item);
            addRecursiveWatches(watcher, item, events, callback, emitter);
        });
    });
    // Watch the dir itself
    if (!missing) watchDir(watcher, dir, events, function (event) {
        if (event && event.name) {
            event.name = path.join(dir, event.name);
        }
        callback(event);
    });
}

function watchDir(watcher, dir, events, callback) {
    dir = path.resolve(dir) + '/';
    watcher.addWatch({
        path: dir,
        watch_for: events,
        callback: callback
    });
}

function watch(watcher, dir, options, emitter) {
    var stream = ReadStream(function () {});

    var callback = function (event) {
        stream.push(event);
    };
    var events = Inotify.IN_CREATE
    if (options.recursive) {
        addRecursiveWatches(watcher, dir, events, callback, emitter);
    } else {
        watchDir(watcher, dir, events, callback);
    }

    stream.on('data', function (data) {
        if (!(data.mask && data.name)) {
            return;
        }
        var mask = data.mask;
        var isDir = !!(mask & Inotify.IN_ISDIR);
        var fullPath = data.name;
        if (fullPath.split('/').length === 1) {
            fullPath = path.join(dir, fullPath);
        }
        fullPath = path.resolve(fullPath);

        if (isDir) {
            addRecursiveWatches(watcher, fullPath, events, callback, emitter)
        }

        if (mask & Inotify.IN_CREATE) {
            emitter.emit('add', fullPath, {
                isDir: isDir,
                mtime: +(new Date())
            });
        }
    });


    return stream;
}
var Inotifyr = module.exports = function(dir, options) {
    var self = this;

    this._options = _.defaults(options || {}, {
        recursive: false
    });

    this._dir = path.resolve(dir);
    this._watcher = new Inotify();
    this._eventStream = watch(this._watcher, dir, this._options, this);
};


inherits(Inotifyr, EventEmitter);

Inotifyr.prototype.close = function () {
    this._watcher.close();
};