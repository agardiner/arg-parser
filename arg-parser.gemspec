GEMSPEC = Gem::Specification.new do |s|
    s.name = "arg-parser"
    s.version = "0.4.1"
    s.authors = ["Adam Gardiner"]
    s.date = "2019-07-04"
    s.summary = "ArgParser is a simple, yet powerful, command-line argument (option) parser"
    s.description = <<-EOQ
        ArgParser is a simple, yet powerful command-line argument parser, with
        support for positional, keyword, flag and rest arguments, any of which
        may be optional or mandatory.
    EOQ
    s.email = "adam.b.gardiner@gmail.com"
    s.homepage = 'https://github.com/agardiner/arg-parser'
    s.require_paths = ['lib']
    s.files = ['README.md', 'LICENSE'] + Dir['lib/**/*.rb']
end
