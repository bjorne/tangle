# &#4034; tangle

`tangle` is a command line tool to combine multiple JSON documents
based on matching keys against each other. It has two modes of
operation - `merge` and `attach` - which are detailed below.

## Merge

`tangle merge` will find matching documents in two or more files and
merge them into one, from right to left.

    $ cat foo.json
    { "id": 1, "foo": 1 }
    $ cat bar.json
    { "id": 1, "bar": 2 }
    $ tangle merge foo.json bar.json
    { "id": 1, "foo": 1, "bar": 2 }

## Attach

`tangle attach` will find matching documents in two or more files and
attach the matching documents from file the second and subsequent
files as a list to the document from the first file.

    $ cat foo.json
    { "id": 1, "foo": 1 }
    $ cat bar.json
    { "id": 1, "bar": 2 }
    $ tangle attach foo.json bar.json
    { "id": 1, "foo": 1, "children": [ { "id": 1, "bar": 2 } ] }
    $ tangle attach -a bars foo.json bar.json
    { "id": 1, "foo": 1, "bars": [ { "id": 1, "bar": 2 } ] }

## FAQ

__Q: I run out of memory when trying to merge an X megabyte file with a Y megabyte file! WTF!__

A: Happy hadooping, dude!

__Q: I need it to support more complex queries__

A: No, you don't. Pre-process your JSON using [process substitution](http://tldp.org/LDP/abs/html/process-sub.html), like so

    $ cat foo.json
    { "id": 1, "foo": 1 }
    $ cat bonkers.json
    { "bonkers": 1, "bar": 2 }
    $ tangle merge foo.json <(cat bonkers.json | sed s,bonkers,id,)
    { "id": 1, "foo": 1, "bar": 2 }
