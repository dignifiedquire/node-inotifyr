expect = require('chai').expect
fs = require 'fs-extended'

Inotifyr = require '../'

describe 'inotifyr', ->
  beforeEach ->
    fs.ensureDirSync './test/fixtures'

  afterEach ->
    fs.deleteDirSync './test/fixtures'

  it 'should watch a directory for file add events', (done) ->
    watcher = new Inotifyr 'test/fixtures'
    watcher.on 'add', (filename, stats) ->
      expect(filename).to.be.eql 'test/fixtures/new.txt'
      expect(stats).to.have.property 'isDir', no
      watcher.close()
      done()

    fs.createFileSync './test/fixtures/new.txt', 'hello world'

  it 'should watch a directory for directory add events', (done) ->
    watcher = new Inotifyr 'test/fixtures'
    watcher.on 'add', (filename, stats) ->
      expect(filename).to.be.eql 'test/fixtures/new'
      expect(stats).to.have.property 'isDir', yes
      watcher.close()
      done()

    fs.createDirSync './test/fixtures/new'
