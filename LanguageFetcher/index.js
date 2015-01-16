var unirest = require('unirest')
var yaml = require('js-yaml')
var fs = require('fs')

var languages = {}

unirest
.get('https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml')
.end(function (response) {
  try {
    var doc = yaml.safeLoad(response.body)
    Object.keys(doc).forEach(function (language) {
      if (!doc[language].extensions) {
        languages[language] = doc[language].filenames[0]
      } else {
        languages[language] = "gistfile1" + doc[language].extensions[0]
      }
    })
    fs.writeFileSync('../Harpia/languages.json', JSON.stringify(languages))
    console.log('Done!')
  } catch (error) {
    console.log(error)
  }
})