expect = require('chai').expect
fs = require 'fs-extended'
path = require 'path'
{spawn, exec} = require 'child_process'
_ = require 'lodash'
diff = require('diff-merge-patch').orderedList.diff

Inotifyr = require '../'


collect = (cmd, args, opts, dir, cb) ->
  child = spawn cmd, args, opts
  child.stdout.on 'data', (data) -> console.log data.toString()
  child.stderr.on 'data', (data) -> console.log data.toString()
  child.on 'close', (code) ->
    throw new Error("Exited with non zero error code: #{code}") if code isnt 0
    exec "find #{dir} -type f -print | wc -l", (err, stdout, stderr) ->
      fileCount = parseInt stdout, 10
      exec "find #{dir} -type d -print | wc -l", (err, stdout, stderr) ->
        dirCount = parseInt stdout, 10
        cb(dirCount + fileCount)



describe 'inotifyr', ->
  beforeEach ->
    fs.ensureDirSync './test/fixtures'

  afterEach ->
    fs.deleteDirSync './test/fixtures'

  it 'should watch a directory for file add events', (done) ->
    watcher = new Inotifyr 'test/fixtures'
    watcher.on 'add', (filename, stats) ->
      expect(filename).to.be.eql path.resolve 'test/fixtures/new.txt'
      expect(stats).to.have.property 'isDir', no
      expect(stats).to.have.property 'mtime'
      watcher.close()
      done()

    fs.createFileSync './test/fixtures/new.txt', 'hello world'

  it 'should watch a directory for directory add events', (done) ->
    watcher = new Inotifyr 'test/fixtures'
    watcher.on 'add', (filename, stats) ->
      expect(filename).to.be.eql path.resolve 'test/fixtures/new'
      expect(stats).to.have.property 'isDir', yes
      expect(stats).to.have.property 'mtime'
      watcher.close()
      done()

    fs.createDirSync './test/fixtures/new'

  [1..5].forEach (i) =>
    it "should register all add events for a git clone (#{i})", (done) ->
        @timeout 5000
        watcher = new Inotifyr 'test/fixtures', recursive: yes
        count = 0
        files = []
        watcher.on 'add', (filename, stats) ->
          files.push filename
          count++
          console.log filename unless stats

        args = ['clone', 'https://github.com/codio/node-demo.git']
        collect 'git', args, {cwd: './test/fixtures'}, 'test/fixtures/node-demo', (total) ->
          console.log diff _.uniq(files), files
          expect(_.uniq(files).length).to.be.eql total
          done()

  [1..5].forEach (i) =>
    it "should register all add events for an unzip action (#{i})", (done) ->
        watcher = new Inotifyr 'test/fixtures', recursive: yes
        count = 0
        files = []
        watcher.on 'add', (filename, stats) ->
          files.push filename
          count++
          console.log filename unless stats

        args = ['-zxf', 'zipFile.tar.gz', '-C', 'fixtures']
        collect 'tar', args, {cwd: './test'}, 'test/fixtures/zipDir', (total) ->
          console.log diff _.uniq(files), files
          expect(_.uniq(files).length).to.be.eql total
          done()

