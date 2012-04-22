# httparty

Makes http fun again!

## Install

```
gem install httparty
```

## Requirements

* multijson and multixml
* You like to party!

## Examples

See http://github.com/jnunemaker/httparty/tree/master/examples

## Command Line Interface

httparty also includes the executable <tt>httparty</tt> which can be
used to query web services and examine the resulting output. By default
it will output the response as a pretty-printed Ruby object (useful for
grokking the structure of output). This can also be overridden to output
formatted XML or JSON. Execute <tt>httparty --help</tt> for all the
options. Below is an example of how easy it is.

```
httparty "http://twitter.com/statuses/public_timeline.json"
```

## Help and Docs

* https://groups.google.com/forum/#!forum/httparty-gem
* http://rdoc.info/projects/jnunemaker/httparty

## Contributing

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself in another branch so I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.
