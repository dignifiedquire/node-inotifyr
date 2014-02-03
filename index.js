
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

function getEventType(mask) {
    var I = Inotify;
    if (mask & Inotify.IN_ACCESS) {
        return 'access';
    } else if (mask & Inotify.IN_ATTRIB) {
        return 'attrib';
    } else if (mask & Inotify.IN_CLOSE_WRITE) {
        return 'close_write';
    } else if (mask & Inotify.IN_CLOSE_NOWRITE) {
        return 'close_nowrite';
    } else if (mask & Inotify.IN_CREATE) {
        return 'create';
    } else if (mask & Inotify.IN_DELETE) {
        return 'delete';
    } else if (mask & Inotify.IN_DELETE_SELF) {
        return 'delete_self';
    } else if (mask & Inotify.IN_MODIFY) {
        return 'modify';
    } else if (mask & Inotify.IN_MOVE_SELF) {
        return 'move_self';
    } else if (mask & Inotify.IN_MOVED_FROM) {
        return 'move_from';
    } else if (mask & Inotify.IN_MOVED_TO) {
        return 'move_to';
    } else if (mask & Inotify.IN_OPEN) {
        return 'open';
    } else if (mask & Inotify.IN_ALL_EVENTS) {
        return 'all';
    } else if (mask & Inotify.IN_CLOSE) {
        return 'close';
    } else if (mask & Inotify.IN_MOVE) {
        return 'move';
    }

}

function emitStatic(emitter, dir) {
    function map(itemPath, stat) {
        var a = {};
        a[itemPath] = stat;
        return a;
    }
    fs.listAll(dir, {
        map: map
    }, function (err, files) {
        _.forEach(files, function (fileObj) {
            var itemPath = Object.keys(fileObj)[0];
            var stat = fileObj[itemPath];
            emitter.emitSafe('add', itemPath, {
                isDir: !stat.isFile(),
                mtime: stat.mtime
            });
        });
    });
}
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
        if (missing) emitStatic(emitter, dir);

        async.each(dirs, function (item) {
            item = path.join(dir, item);
            addRecursiveWatches(watcher, item, events, callback, emitter);
        });
    });
    // Watch the dir itself
    if (!missing) watchDir(watcher, dir, events, emitter, function (event) {
        if (event && event.name) {
            event.name = path.join(dir, event.name);
        }
        callback(event);
    });
}

function watchDir(watcher, dir, events, emitter, callback) {
    dir = path.resolve(dir) + '/';
    var wd = watcher.addWatch({
        path: dir,
        watch_for: events,
        callback: callback
    });
    if (_.isNumber(wd) && wd > 0) {
        emitStatic(emitter, dir);
    }
}

function watch(watcher, dir, options, emitter) {
    var stream = ReadStream(function () {});

    var callback = function (event) {
        stream.push(event);
    };
    var events = Inotify.IN_CREATE;
    if (options.recursive) {
        addRecursiveWatches(watcher, dir, events, callback, emitter);
    } else {
        watchDir(watcher, dir, events, emitter, callback);
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
        var eventType = getEventType(mask);
        if (eventType === 'create') {
            emitter.emitSafe('add', fullPath, {
                isDir: isDir,
                mtime: +(new Date)
            });
        } else if (eventType === 'move_to' || eventType === 'move_from') {
            //console.log('%s: %s', eventType, fullPath);
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
    this._emitted = [];
};


inherits(Inotifyr, EventEmitter);


// Only emit when the key was not yet emitted
Inotifyr.prototype.emitSafe = function (event, key, value) {
    var i = _.findIndex(this._emitted, function (val) {
       return val === key;
    });
    if (i > -1) {
        //this._emitted.splice(i, 1);
        return;
    }
    this._emitted.push(key);
    this.emit(event, key, value);
};

Inotifyr.prototype.close = function () {
    return this._watcher.close();
};