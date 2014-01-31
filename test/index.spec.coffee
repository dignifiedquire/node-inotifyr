expect = require('chai').expect
fs = require 'fs-extended'
path = require 'path'
{spawn, exec} = require 'child_process'
_ = require 'lodash'
diff = require('diff-merge-patch').orderedList.diff

Inotifyr = require '../'

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

        git = spawn 'git', ['clone', 'https://github.com/codio/node-demo.git'], {cwd: './test/fixtures'}
        git.stdout.on 'data', (data) -> console.log data.toString()
        git.stderr.on 'data', (data) -> console.log data.toString()
        git.on 'close', (code) ->
          expect(code).to.be.eql 0

          exec 'find test/fixtures/node-demo -type f -print | wc -l', (err, stdout, stderr) ->
            fileCount = parseInt stdout, 10
            exec 'find test/fixtures/node-demo -type d -print | wc -l', (err, stdout, stderr) ->
              dirCount = parseInt stdout, 10
              console.log diff _.uniq(files), files
              expect(_.uniq(files).length).to.be.eql(fileCount + dirCount)
              done()

  [1..5].forEach (i) =>
    it "should register all add events for an unzip action (#{i})", (done) ->
        @timeout 5000
        watcher = new Inotifyr 'test/fixtures', recursive: yes
        count = 0
        files = []
        watcher.on 'add', (filename, stats) ->
          files.push filename
          count++
          console.log filename unless stats

        tar = spawn 'tar', ['-zxf', 'zipFile.tar.gz', '-C', 'fixtures'], {cwd: './test'}
        tar.stdout.on 'data', (data) -> console.log data.toString()
        tar.stderr.on 'data', (data) -> console.log data.toString()
        tar.on 'close', (code) ->
          expect(code).to.be.eql 0

          exec 'find test/fixtures/zipDir -type f -print | wc -l', (err, stdout, stderr) ->
            fileCount = parseInt stdout, 10
            exec 'find test/fixtures/zipDir -type d -print | wc -l', (err, stdout, stderr) ->
              dirCount = parseInt stdout, 10
              console.log diff _.uniq(files), files
              expect(_.uniq(files).length).to.be.eql(fileCount + dirCount)
              done()
