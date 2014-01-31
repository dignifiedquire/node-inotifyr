expect = require('chai').expect
fs = require 'fs-extended'

Inotifyr = require '../'

describe 'inotifyr', ->
  beforeEach ->
    fs.ensureDirSync './fixtures'

  afterEach ->
    fs.deleteDirSync './fixtures'

  it 'should watch a directory for add events', (done) ->
    watcher = new Inotifyr 'fixtures'
    watcher.on 'add', (filename, stats) ->
      expect(filename).to.be.eql 'fixtures/new.txt'
      expect(stats).to.have.property 'isDir', no
      expect(stats).to.have.property 'mtime'
      watcher.close()
      done()

    fs.createFileSync './fixtures/new.txt', 'hello world'
