
var inherits = require('util').inherits;
var EventEmitter = require('events').EventEmitter;
var path = require('path');

var callbackToStream = require('read-stream/callback');
var Inotify = require('inotify').Inotify;
var through = require('through2');


function watch(watcher, dir) {
    return callbackToStream(function (cb) {
        watcher.addWatch({
            path: dir,
            watch_for: Inotify.IN_CREATE,
            callback: function (event) {
                cb(null, event);
            }
        });
    });
}
var Inotifyr = module.exports = function(dir, options) {
    var self = this;

    this._dir = dir;
    this._watcher = new Inotify();
    this._eventStream = watch(this._watcher, dir);
    this._eventStream.on('data', function (data) {
        if (data.mask && data.name) {
            var mask = data.mask;
            if (mask & Inotify.IN_CREATE) {
                self.emit('add', path.join(self._dir, data.name), {
                    isDir: !!(mask & Inotify.IN_ISDIR)
                });
            }
        }
    });
};


inherits(Inotifyr, EventEmitter);

Inotifyr.prototype.close = function () {
    this._watcher.close();
};