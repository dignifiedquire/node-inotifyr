// Bit Operations
// ==============

// Dependencies
// ------------

var Inotify = require('inotify').Inotify;
var _ = require('lodash');

// Map of strings to bit masks
var eventMap = {
    access: Inotify.IN_ACCESS,
    attrib: Inotify.IN_ATTRIB,
    close_write: Inotify.IN_CLOSE_WRITE,
    close_nowrite: Inotify.IN_CLOSE_NOWRITE,
    create: Inotify.IN_CREATE,
    delete: Inotify.IN_DELETE,
    delete_self: Inotify.IN_DELETE_SELF,
    modify: Inotify.IN_MODIFY,
    move_self: Inotify.IN_MOVE_SELF,
    move_from: Inotify.IN_MOVED_FROM,
    move_to: Inotify.IN_MOVED_TO,
    open: Inotify.IN_OPEN,
    all: Inotify.IN_ALL_EVENTS,
    close: Inotify.IN_CLOSE,
    move: Inotify.IN_MOVE,
    onlydir: Inotify.IN_ONLYDIR,
    dont_follow: Inotify.IN_DONT_FOLLOW,
    oneshot: Inotify.IN_ONESHOT
};

// Convert a string to the corresponding bit mask.
//
// event - String
//
// Returns a binary number.
function toBitMask(event) {
    if (!_.has(eventMap, event)) {
        throw new Error('Unkown event: ' + event);
    }
    return eventMap[event];
}

// Create a bit mask from an array of bit masks.
//
// events - Array of binary numbers.
//
// Returns a binary number.
function reduceMask(events) {
    return _.reduce(events, function (acc, current) {
        return acc | current;
    }, 0);
}

// Turn a list of string events into a single bit mask.
//
// events - Array of strings.
//
// Returns a binary number.
function maskEvents(events) {
    return reduceMask(_.map(events, toBitMask));
}

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
    } else if (mask & Inotify.IN_IGNORED) {
        return 'ignored';
    } else if (mask & Inotify.IN_ISDIR) {
        return 'isdir';
    } else if (mask & Inotify.IN_Q_OVERFLOW) {
        return 'q_overflow';
    } else if (mask & Inotify.IN_UNMOUNT) {
        return 'unmount';
    }

    throw new Error('Unkown event type: ' + mask);
}

// Add additional flags to a given mask.
//
// mask  - Number
// flags - Object
//
// Returns a number.
function addFlags(mask, flags) {
    if (flags.onlydir) mask = mask | Inotify.IN_ONLYDIR;
    if (flags.dont_follow) mask = mask | Inotify.IN_DONT_FOLLOW;
    if (flags.oneshot) mask = mask | Inotify.IN_ONESHOT;
    return mask;
}


module.exports = {
    getEventType: getEventType,
    maskEvents: maskEvents,
    toBitMask: toBitMask,
    reduceMask: reduceMask,
    addFlags: addFlags
};