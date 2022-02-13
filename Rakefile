task default: [:compile]

task :compile do
  sh 'opal -c --gem ovto --gem parser app.rb > public/app.js'
end
