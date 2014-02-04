chai = require 'chai'
chai.use require 'sinon-chai'
expect = chai.expect
fs = require 'fs-extended'
path = require 'path'
{spawn, exec} = require 'child_process'
_ = require 'lodash'
diff = require('diff-merge-patch').set.diff
sinon = require 'sinon'


Inotifyr = require '../../'

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


describe 'Inotifyr Events', ->
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

  describe 'access', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'should watch a directory for file access events', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'access'
      watcher.on 'access', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.readFileSync './test/fixtures/new.txt'

  describe 'attrib', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'should watch a directory for file attrib events', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'attrib'
      watcher.on 'attrib', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.chmodSync './test/fixtures/new.txt', '0755'

  describe 'close_write', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a file in write mode was closed', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'close_write'
      watcher.on 'close_write', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fd = fs.openSync './test/fixtures/new.txt', 'w'
      fs.close fd

  describe 'close_nowrite', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a file in read mode was closed', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'close_nowrite'

      # Hack as close_nowrite is emitted quite often
      files = []
      watcher.on 'close_nowrite', (filename, stats) -> files.push filename

      fd = fs.openSync './test/fixtures/new.txt', 'r'
      fs.close fd

      _.delay ->
        expect(files).to.contain path.resolve 'test/fixtures/new.txt'
        watcher.close()
        done()
      , 50


  describe 'delete_self', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when the watched directory was removed', (done) ->
      fs.createDirSync './test/fixtures/new'

      watcher = new Inotifyr 'test/fixtures/new', events: 'delete_self'
      watcher.on 'delete_self', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.deleteDirSync 'test/fixtures/new'

    it 'emits when the watched file was removed', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures/new.txt', events: 'delete_self'
      watcher.on 'delete_self', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      # Without this delay the watcher doesn't pick up the deletion sometimes
      _.delay ->
        fs.deleteFileSync './test/fixtures/new.txt'
      , 10

  describe 'move_self', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when the watched directory was moved', (done) ->
      fs.createDirSync './test/fixtures/new'
      watcher = new Inotifyr 'test/fixtures/new', events: 'move_self'
      watcher.on 'move_self', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveDirSync 'test/fixtures/new', 'test/fixtures/new2'

    it 'emits when the watched file was moved', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures/new.txt', events: 'move_self'
      watcher.on 'move_self', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveFileSync 'test/fixtures/new.txt', 'test/fixtures/new2.txt'

  describe 'move_from', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a directory was moved', (done) ->
      fs.createDirSync './test/fixtures/new'

      watcher = new Inotifyr 'test/fixtures', events: 'move_from'
      watcher.on 'move_from', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveDirSync 'test/fixtures/new', 'test/fixtures/new2'

    it 'emits when a file was moved', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'move_from'
      watcher.on 'move_from', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveFileSync 'test/fixtures/new.txt', 'test/fixtures/new2.txt'

  describe 'move_to', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a directory was moved', (done) ->
      fs.createDirSync './test/fixtures/new'

      watcher = new Inotifyr 'test/fixtures', events: 'move_to'
      watcher.on 'move_to', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new2'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveDirSync 'test/fixtures/new', 'test/fixtures/new2'

    it 'emits when a file was moved', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'move_to'
      watcher.on 'move_to', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new2.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveFileSync 'test/fixtures/new.txt', 'test/fixtures/new2.txt'

  describe 'move', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a directory was moved', (done) ->
      fs.createDirSync './test/fixtures/new'

      watcher = new Inotifyr 'test/fixtures', events: 'move'
      watcher.on 'move', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new2'
        expect(stats).to.have.property 'from', path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveDirSync 'test/fixtures/new', 'test/fixtures/new2'

    it 'emits when a file was moved', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'move'
      watcher.on 'move', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new2.txt'
        expect(stats).to.have.property 'from', path.resolve 'test/fixtures/new.txt'
        expect(stats).to.have.property 'isDir', no
        expect(stats).to.have.property 'mtime'
        watcher.close()
        done()

      fs.moveFileSync 'test/fixtures/new.txt', 'test/fixtures/new2.txt'

    it 'handles recursive watch after a move', (done) ->
      fs.createDirSync  './test/fixtures/new'
      fs.createFileSync './test/fixtures/new/hello.txt', 'hello'

      watcher = new Inotifyr 'test/fixtures', {
        recursive: yes,
        events: ['move', 'create']
      }

      watcher.on 'move', (filename, stats) ->
        expect(filename).to.be.eql path.resolve 'test/fixtures/new2'
        expect(stats).to.have.property 'from', path.resolve 'test/fixtures/new'
        expect(stats).to.have.property 'isDir', yes
        expect(stats).to.have.property 'mtime'

      files = []
      watcher.on 'create', (filename, stats) -> files.push filename

      fs.moveDir './test/fixtures/new', './test/fixtures/new2', (err) ->
        expect(files).to.not.contain path.resolve 'test/fixtures/new2/hello.txt'
        _.delay ->
          fs.createFile './test/fixtures/new2/test.txt', 'hello', (err) ->
            expect(files).to.contain path.resolve 'test/fixtures/new2/test.txt'
            watcher.close()
            done()
        , 10


  describe 'close', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a file is closed', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'
      fs.createFileSync './test/fixtures/new2.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'close'

      # Hack as close_nowrite is emitted quite often
      files = []
      watcher.on 'close', (filename, stats) -> files.push filename

      fd = fs.openSync './test/fixtures/new.txt', 'r'
      fs.close fd
      fd = fs.openSync './test/fixtures/new2.txt', 'w'
      fs.close fd

      _.delay ->
        expect(files).to.contain path.resolve 'test/fixtures/new.txt'
        expect(files).to.contain path.resolve 'test/fixtures/new2.txt'
        watcher.close()
        done()
      , 10

  describe 'open', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'emits when a file is opened', (done) ->
      fs.createFileSync './test/fixtures/new.txt', 'hello world'

      watcher = new Inotifyr 'test/fixtures', events: 'open'
      files = []
      watcher.on 'open', (filename, stats) -> files.push filename

      fs.open './test/fixtures/new.txt', 'w', (err, fd) ->
        fs.close fd

        _.delay ->
          expect(files).to.contain path.resolve 'test/fixtures/new.txt'
          watcher.close()
          done()
        , 10

  describe.skip 'flags', ->
    describe 'onlydir', ->
      beforeEach -> fs.ensureDirSync './test/fixtures'
      afterEach -> fs.deleteDirSync './test/fixtures'

      it 'only watches a directory path', ->

    describe 'dont_follow', ->
      beforeEach -> fs.ensureDirSync './test/fixtures'
      afterEach -> fs.deleteDirSync './test/fixtures'

      it 'doesn\'t follow symbolic links', ->
    describe 'oneshot', ->
      beforeEach -> fs.ensureDirSync './test/fixtures'
      afterEach -> fs.deleteDirSync './test/fixtures'

      it 'emits only one event', ->


  describe 'ignores initial create events', ->
    beforeEach -> fs.ensureDirSync './test/fixtures'
    afterEach -> fs.deleteDirSync './test/fixtures'

    it 'doesn\'t emit initial add events when watching a filled directory', (done) ->
      fs.createDirSync './test/fixtures/watchme'
      [1..5].forEach (i) ->
        fs.createFileSync "./test/fixtures/#{i}.txt", 'hello'
        fs.createFileSync "./test/fixtures/watchme/#{i}.txt", 'world'

      watcher = new Inotifyr 'test/fixtures', {
        events: ['move', 'delete', 'create', 'modify']
        recursive: yes
      }
      files = []
      watcher.on 'create', (filename, stats) -> files.push filename

      fs.createFileSync './test/fixtures/hello.txt', 'hello'
      _.delay ->
        [1..5].forEach (i) ->
          expect(files).to.not.contain path.resolve "test/fixtures/#{i}.txt"
          expect(files).to.not.contain path.resolve "test/fixtures/watchme/#{i}.txt"
        expect(files).to.contain path.resolve 'test/fixtures/hello.txt'
        watcher.close()
        done()
      , 10



