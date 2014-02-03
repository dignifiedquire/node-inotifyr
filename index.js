
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

var Inotifyr = module.exports = function (dir, options) {
    EventEmitter.call(this);
    var self = this;

    this._options = _.defaults(options || {}, {
        recursive: false
    });

    this._dir = path.resolve(dir);
    this._watcher = new Inotify();
    this._eventStream = this._watch(this._dir, this._options);
    this._emitted = [];
};


inherits(Inotifyr, EventEmitter);

Inotifyr.prototype._emitStatic = function (dir) {
    var self = this;
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
            self._emitSafe('add', itemPath, {
                isDir: !stat.isFile(),
                mtime: stat.mtime
            });
        });
    });
}

Inotifyr.prototype._addRecursiveWatches = function (dir, events, callback, missing) {
    var self = this;
    // Watch all directories inside dir
    fs.listDirs(dir, function (err, dirs) {
        if (err) {
            if (err.code === ERROR.ENOENT) {
                // If we can't read the directory yet try again a little bit later.
                _.delay(function () {
                    self._addRecursiveWatches(dir, events, callback, true);
                }, 10);
            }
            return;
        }
        if (missing) self._emitStatic(dir);

        async.each(dirs, function (item) {
            item = path.join(dir, item);
            self._addRecursiveWatches(item, events, callback);
        });
    });

    // Watch the dir itself
    if (!missing) self._watchDir(dir, events, function (event) {
        if (event && event.name) {
            event.name = path.join(dir, event.name);
        }
        callback(event);
    });
}

Inotifyr.prototype._watchDir = function (dir, events, callback) {
    dir = path.resolve(dir) + '/';
    var wd = this._watcher.addWatch({
        path: dir,
        watch_for: events,
        callback: callback
    });
    if (_.isNumber(wd) && wd > 0) {
        this._emitStatic(dir);
    }
}



Inotifyr.prototype._watch = function (dir, options) {
    var stream = ReadStream(function () {});
    var self = this;
    var callback = function (event) {
        stream.push(event);
    };
    var events = Inotify.IN_CREATE;
    if (options.recursive) {
        this._addRecursiveWatches(dir, events, callback);
    } else {
        this._watchDir(dir, events, callback);
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
            self._addRecursiveWatches(fullPath, events, callback)
        }
        var eventType = getEventType(mask);
        if (eventType === 'create') {
            self._emitSafe('add', fullPath, {
                isDir: isDir,
                mtime: +(new Date)
            });
        } else if (eventType === 'move_to' || eventType === 'move_from') {
            //console.log('%s: %s', eventType, fullPath);
        }
    });
    return stream;
}


// Only emit when the key was not yet emitted
Inotifyr.prototype._emitSafe = function (event, key, value) {
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