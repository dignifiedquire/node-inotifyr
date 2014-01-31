expect = require('chai').expect
fs = require 'fs-extended'
cp = require 'child_process'
{spawn, exec} = require 'child_process'

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


  it 'should register all add events for a git clone', (done) ->
      @timeout 5000
      watcher = new Inotifyr 'test/fixtures'
      count = 0
      watcher.on 'add', (filename, stats) ->
        count++

      git = spawn 'git', ['clone', 'https://github.com/codio/node-demo.git', 'test/fixtures/node-demo']
      git.stdout.on 'data', (data) -> console.log data.toString()
      git.stderr.on 'data', (data) -> console.log data.toString()
      git.on 'close', (code) ->
        expect(code).to.be.eql 0

        exec 'find test/fixtures/node-demo -type f -print | wc -l', (err, stdout, stderr) ->
          expect(count).to.be.eql parseInt(stdout, 10)
          done()

