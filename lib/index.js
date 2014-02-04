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


// Is the given timestamp in still between now and the upper limit.
//
// timestamp - Number,
// limit     - Number
//
// Returns a boolean.
function inRange(timestamp, limit) {
    return (new Date()) - timestamp < limit;
}

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

    this._path = path.resolve(dir);
    this._isDir = fs.statSync(this._path).isDirectory();
    this._watcher = new Inotify();
    this._eventStream = this._watch(this._path, this._options);

    this._emitted = {};
    this._clean();
    // Used to correlate move_from and move_to events.
    this._cookieJar = {};
};


inherits(Inotifyr, EventEmitter);

// Private Methods
// ---------------

// Clean the emitted list every 30 seconds
Inotifyr.prototype._clean = function () {
    var self = this;
    _.delay(function () {
        // Clean all that are older than 5 seconds
        _.forEach(self._emitted, function (key, timestamp) {
            if (inRange(timestamp, 5 * 1000)) {
                delete self._emitted[key];
            }
        });
    }, 30 * 1000);
};

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

// Recursively add watches to a given directory for the events passed.
//
// dir      - String,
// events   - Number, bit mask for the events.
// initial  - Boolean, is this the initial add?
// callback - Function, called for each event that occurs.
Inotifyr.prototype._addRecursiveWatches = function (dir, events, initial, callback) {
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
            self._addRecursiveWatches(item, events, initial, callback);
        });
    });

    // Watch the dir itself
    self._watchDir(dir, events, initial, function (event) {
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
// initial  - Boolean, is this the initial add?
// callback - Function, called for each event that occurs.
Inotifyr.prototype._watchDir = function (dir, events, initial, callback) {
    dir = path.resolve(dir);
    if (this._isDir) dir = dir + '/';
    var wd = this._watcher.addWatch({
        path: dir,
        watch_for: events,
        callback: callback
    });
    if (!initial && _.isNumber(wd) && wd > 0) {
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
        this._addRecursiveWatches(dir, events, true, callback);
    } else {
        this._watchDir(dir, events, true, callback);
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

        var eventType = bits.getEventType(mask);
        var stat = {
            isDir: isDir,
            mtime: +(new Date())
        };

        switch (eventType) {
        case 'create':
            if (isDir) {
                self._addRecursiveWatches(fullPath, events, false, callback);
            }
            self._emitSafe('create', fullPath, stat);
            break;
        case 'delete_self':
        case 'move_self':
            stat.path = path.resolve(dir);
            stat.isDir = self._isDir;
            self.emit(eventType, fullPath, stat);
            break;
        case 'close_write':
        case 'close_nowrite':
            self.emit(eventType, fullPath, stat);
            self.emit('close', fullPath, stat);
            break;
        case 'move_from':
            self._cookieJar[data.cookie] = fullPath;
            self.emit(eventType, fullPath, stat);
            break;
        case 'move_to':
            stat.from = self._getPathFromCookie(data.cookie);
            if (isDir) {
                self._addRecursiveWatches(fullPath, events, false, callback);
            }
            self.emit(eventType, fullPath, stat);
            self.emit('move', fullPath, stat);
            break;
        default:
            self.emit(eventType, fullPath, stat);
            break;
        }
    };
};

// Get the path from a given cookie
//
// cookie - Number.
//
// Returns a string.
Inotifyr.prototype._getPathFromCookie = function (cookie) {
    if (!_.has(this._cookieJar, cookie)) return;

    var cookiePath = this._cookieJar[cookie];
    //delete this._cookieJar[cookie];
    return cookiePath;
};

// Only emit when the key was not yet emitted.
//
// event - String,
// key   - String,
// value - Object,
Inotifyr.prototype._emitSafe = function (event, key, value) {
    if (_.has(this._emitted, event + ':' + key)) return;

    this._emitted[event + ':' + key] = +(new Date());
    this.emit(event, key, value);
};

// Public Methods
// --------------

// Close the file watcher.
Inotifyr.prototype.close = function () {
    return this._watcher.close();
};