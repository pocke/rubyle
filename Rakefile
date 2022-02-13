task default: [:compile]

task :compile do
  sh 'opal -c -I . --gem ovto --gem parser app.rb > public/app.js'
end

task :watch do
  sh 'ifchanged app.rb hint.rb --do "rake compile"'
end
