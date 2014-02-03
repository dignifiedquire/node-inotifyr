chai = require 'chai'
chai.use require 'sinon-chai'
expect = chai.expect
fs = require 'fs-extended'
sinon = require 'sinon'

Inotifyr = require '../../'

describe 'Inotifyr', ->
  describe '_emitSafe', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'only emits events that are not yet listed', ->
      watcher = new Inotifyr 'test/fixtures', recursive: yes
      watcher._emitted['create:hello/world'] = +(new Date())
      sinon.stub watcher, 'emit'

      watcher._emitSafe 'create', 'hello/world'
      watcher._emitSafe 'create', 'hello/world/hello'

      expect(watcher.emit).to.have.been.calledOnce
      expect(watcher.emit).to.have.been.calledWith 'create', 'hello/world/hello'


