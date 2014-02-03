// Inotifyr
// ========
//
// Because file watching is hard.

// Dependencies
// ------------

var inherits = require('util').inherits;
var EventEmitter = require('events').EventEmitter;
var path = require('path');
var fs = require('fs-extended');

var ReadStream = require('read-stream');
var Inotify = require('inotify').Inotify;
var _ = require('lodash');
var async = require('async');

var bits = require('./bits');

// Local Variables
// ---------------

// List of error codes
var ERROR = {
    ENOENT: 'ENOENT',
    ELOOP: 'ELOOP',
    EACCES: 'EACCES'
};

// Constructor
//
// dir     - String, the path to watch
// options - Object.
var Inotifyr = module.exports = function (dir, options) {
    EventEmitter.call(this);
    this._options = _.defaults(options || {}, {
        recursive: false,
        events: ['create', 'modify', 'delete', 'move'],
        onlydir: false,
        'dont_follow': false,
        oneshot: false
    });

    if (_.isString(this._options.events)) this._options.events = [this._options.events];

    this._dir = path.resolve(dir);
    this._watcher = new Inotify();
    this._eventStream = this._watch(this._dir, this._options);
    this._emitted = [];
};


inherits(Inotifyr, EventEmitter);

// Private Methods
// ---------------

// Stat a dir and emit create events for all the items inside.
//
// dir - String.
Inotifyr.prototype._emitStatic = function (dir) {
    var self = this;
    function map(itemPath, stat) {
        var a = {};
        a[itemPath] = stat;
        return a;
    }
    fs.listAll(dir, {map: map}, function (err, files) {
        // If we can't read the directory don't bother.
        if (err) {
            return;
        }
        _.forEach(files, function (fileObj) {
            var itemPath = Object.keys(fileObj)[0];
            var stat = fileObj[itemPath];
            self._emitSafe('create', itemPath, {
                isDir: !stat.isFile(),
                mtime: stat.mtime
            });
        });
    });
};

// Recursivel add watches to a given directory for the events passed.
//
// dir      - String,
// events   - Number, bit mask for the events.
// callback - Function, called for each event that occurs.
Inotifyr.prototype._addRecursiveWatches = function (dir, events, callback) {
    var self = this;
    // Watch all directories inside dir
    fs.listDirs(dir, function (err, dirs) {
        if (err) {
            // Ignore some errors
            if (!_.contains([ERROR.EACCES, ERROR.ENOENT, ERROR.ELOOP], err.code)) {
                return self.emit('error', err);
            }
        }
        if (_.isEmpty(dirs)) {
            return;
        }
        async.each(dirs, function (item) {
            item = path.join(dir, item);
            self._addRecursiveWatches(item, events, callback);
        });
    });

    // Watch the dir itself
    self._watchDir(dir, events, function (event) {
        if (event && event.name) {
            event.name = path.join(dir, event.name);
        }
        callback(event);
    });
};

// Watch a directory.
//
// dir      - String, the path to the directory.
// events   - Number, bit mask for the events.
// callback - Function, called for each event that occurs.
Inotifyr.prototype._watchDir = function (dir, events, callback) {
    dir = path.resolve(dir) + '/';
    var wd = this._watcher.addWatch({
        path: dir,
        'watch_for': events,
        callback: callback
    });
    if (_.isNumber(wd) && wd > 0) {
        this._emitStatic(dir);
    }
};

// Watch
//
// dir     - String,
// options - Object,
//
// Returns a read stream.
Inotifyr.prototype._watch = function (dir, options) {
    var stream = new ReadStream(function () {});
    var callback = function (event) {
        stream.push(event);
    };
    var events = bits.maskEvents(options.events);
    events = bits.addFlags(events, options);
    if (options.recursive) {
        this._addRecursiveWatches(dir, events, callback);
    } else {
        this._watchDir(dir, events, callback);
    }

    stream.on('data', this._createDataHandler(dir, events, callback));
    return stream;
};

// Create a data event handler
//
// dir      - String, the path to the directory.
// events   - Number, bit mask for the events.
// callback - Function, called for each event that occurs.
//
// Returns a function.
Inotifyr.prototype._createDataHandler = function (dir, events, callback) {
    var self = this;
    return function (data) {
        if (!data.mask) return;

        var mask = data.mask;
        var isDir = !!(mask & Inotify.IN_ISDIR);
        var fullPath = data.name || '';
        if (fullPath.split('/').length === 1)  fullPath = path.join(dir, fullPath);
        fullPath = path.resolve(fullPath);
        if (isDir) self._addRecursiveWatches(fullPath, events, callback);

        var eventType = bits.getEventType(mask);
        var stat = {
            isDir: isDir,
            mtime: +(new Date())
        };

        switch (eventType) {
        case 'create':
            self._emitSafe('create', fullPath, stat);
            break;
        case 'delete_self':
            stat.path = path.resolve(dir);
            self.emit(eventType, fullPath, stat);
            break
        default:
            self.emit(eventType, fullPath, stat);
            break;
        }
    };
};

// Only emit when the key was not yet emitted.
//
// event - String,
// key   - String,
// value - Object,
Inotifyr.prototype._emitSafe = function (event, key, value) {
    var i = _.findIndex(this._emitted, function (val) {
        return val === event + ':' + key;
    });
    if (i > -1) return;

    this._emitted.push(event + ':' + key);
    this.emit(event, key, value);
};

// Public Methods
// --------------

// Close the file watcher.
Inotifyr.prototype.close = function () {
    return this._watcher.close();
};