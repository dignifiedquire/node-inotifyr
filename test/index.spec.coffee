chai = require 'chai'
chai.use require 'sinon-chai'
expect = chai.expect
fs = require 'fs-extended'
path = require 'path'
{spawn, exec} = require 'child_process'
_ = require 'lodash'
diff = require('diff-merge-patch').set.diff
sinon = require 'sinon'


Inotifyr = require '../'

touch = (filePath) ->
  fd = fs.openSync filePath, 'w'
  fs.close fd

collect = (cmd, args, opts, dir, cb) ->
  child = spawn cmd, args, opts
  child.stderr.on 'data', (data) -> console.log data.toString()
  child.on 'close', (code) ->
    throw new Error("Exited with non zero error code: #{code}") if code isnt 0
    fs.listAll dir, {recursive: yes}, (err, list) ->
      list = _.map(list, (item) -> path.resolve path.join dir, item)
      list.push path.resolve dir
      cb list



describe 'inotifyr', ->
  describe 'create', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'should watch a directory for file create events', (done) ->
      watcher = new Inotifyr 'test/fixtures', events: 'create'
      watcher.on 'create', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.createFileSync './test/fixtures/new.txt', 'hello world'

    it 'should watch a directory for directory create events', (done) ->
      watcher = new Inotifyr 'test/fixtures', events: 'create'
      watcher.on 'create', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.createDirSync './test/fixtures/new'

    it 'should register all create events for a git clone', (done) ->
      @timeout 5000
      watcher = new Inotifyr 'test/fixtures', {recursive: yes, events: 'create'}
      files = []
      watcher.on 'create', (filename, stats) ->
        files.push filename
        console.log filename unless stats

      args = ['clone', 'https://github.com/codio/node-demo.git']
      collect 'git', args, {cwd: './test/fixtures'}, 'test/fixtures/node-demo', (realFiles) ->
        expect(_.uniq files).to.be.eql files
        realFiles.forEach (file) ->
          return if file.match /\.git/
          expect(files).to.contain file
        done()

    it 'should register all create events for an unzip action', (done) ->
      watcher = new Inotifyr 'test/fixtures', {recursive: yes, events: 'create'}
      files = []
      watcher.on 'create', (filename, stats) ->
        files.push filename
        console.log filename unless stats

      args = ['-zxf', 'zipFile.tar.gz', '-C', 'fixtures']
      collect 'tar', args, {cwd: './test'}, 'test/fixtures/zipDir', (realFiles) ->
        expect(_.uniq files).to.be.eql files
        expect(files.length).to.be.eql realFiles.length
        done()

  describe 'modify', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'should watch a directory for file modify events', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'modify'
      watcher.on 'modify', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      touch './test/fixtures/new.txt', 'w'

  describe 'delete', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'should watch a directory for file delete events', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'
      watcher = new Inotifyr 'test/fixtures', events: 'delete'
      watcher.on 'delete', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.deleteFileSync './test/fixtures/new.txt'

    it 'should watch a directory for directory delete events', (done) ->
      fs.createDirSync './test/fixtures/new'
      watcher = new Inotifyr 'test/fixtures', events: 'delete'
      watcher.on 'delete', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.deleteDirSync './test/fixtures/new'


  describe '_emitSafe', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'only emits events that are not yet listed', ->
      watcher = new Inotifyr 'test/fixtures', recursive: yes
      watcher._emitted.push 'hello/world'
      sinon.stub watcher, 'emit'

      watcher._emitSafe 'create', 'hello/world'
      watcher._emitSafe 'create', 'hello/world/hello'

      expect(watcher.emit).to.have.been.calledOnce
      expect(watcher.emit).to.have.been.calledWith 'create', 'hello/world/hello'


