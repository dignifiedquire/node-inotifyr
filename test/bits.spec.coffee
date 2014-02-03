chai = require 'chai'
expect = chai.expect

{Inotify} = require 'inotify'
bits = require '../lib/bits'

describe 'bit operations', ->
  describe 'getEventType', ->
    it 'returns the correct event string for a given bit mask', ->
      expect(bits.getEventType Inotify.IN_ACCESS).to.be.eql 'access'
      expect(bits.getEventType Inotify.IN_OPEN).to.be.eql 'open'


  describe 'toBitMask', ->
    it 'returns the corecct bit mask for a given event string', ->
      expect(bits.toBitMask 'create').to.be.eql Inotify.IN_CREATE
      expect(bits.toBitMask 'open').to.be.eql Inotify.IN_OPEN

    it 'throws on an unkown event', ->
      expect(-> bits.toBitMask 'world').to.throw

  describe 'reduceMask', ->
    it 'handles a list with a single element', ->
      expect(bits.reduceMask [Inotify.IN_CREATE]).to.be.eql Inotify.IN_CREATE
      expect(bits.reduceMask [Inotify.IN_MODIFY]).to.be.eql Inotify.IN_MODIFY

    it 'handles a list with a multiple element', ->
      list = [Inotify.IN_CREATE, Inotify.IN_MODIFY, Inotify.IN_MOVE]
      expected = Inotify.IN_CREATE | Inotify.IN_MODIFY | Inotify.IN_MOVE
      expect(bits.reduceMask list).to.be.eql expected

  describe 'maskEvents', ->
    it 'handles a list with a single element', ->
      expect(bits.maskEvents ['create']).to.be.eql Inotify.IN_CREATE
      expect(bits.maskEvents ['modify']).to.be.eql Inotify.IN_MODIFY

    it 'handles a list with a multiple element', ->
      expected = Inotify.IN_CREATE | Inotify.IN_MODIFY | Inotify.IN_MOVE
      expect(bits.maskEvents ['create', 'modify', 'move']).to.be.eql expected


