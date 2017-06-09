#!/usr/bin/env node

let fs = require('fs')
let path = require('path')
let glob = require('glob')

function replaceStringsIn (file) {
  fs.readFile(file, 'utf8', function (err, str) {
    if (err) throw err

    let replace = function (source, dest) {
      str = str.split(source).join(dest)
    }

    replace('http://localhost:8080', 'https://example.cypress.io')
    replace("to.eq('localhost:8080')", "to.eq('example.cypress.io')")
    replace("to.eq('localhost')", "to.eq('example.cypress.io')")
    replace("to.eq('8080')", "to.eq('')")
    replace("to.eq('http:')", "to.eq('https:')")
    replace("imgSrcToDataURL('/assets", "imgSrcToDataURL('https://example.cypress.io/assets")

    fs.writeFile(file, str, function (err) {
      if (err) throw err

      // eslint-disable-next-line no-console
      console.log(`Converted ${path.relative(process.cwd(), file)} successfully.`)
    })
  })
}

glob('./app/**/*.html', { realpath: true }, function (err, files) {
  if (err) throw err

  let spec = path.join(process.cwd(), 'cypress', 'integration', 'example_spec.js')

  files.push(spec)

  files.forEach(function (file) {
    return replaceStringsIn(file)
  })
})
