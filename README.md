# prunedocker

Small utility to prune docker image tags from a dockerhub repository. This will keep the most `k` recent tags in a docker hub repository

## running it

You can either grab the code in the [repository](https://github.com/paulosuzart/prunedocker) and simply run:

`racket prunedocker.rkt --help` and a message like this should be displayed:

```
Prune DockerHub [ <option> ... ]
 where <option> is one of
  -u <u>, --user <u> : Dockerhub Login
  -p <p>, --password <p> : DockerHub password
  -r <r>, --repo <r> : Dockerhub repository
  -k <k>, --keep <k> : Keeps k tags in the repo. Will delete the remaining older tags
  --dry-run : Just lists tags that will be dropped without actually dropping them
  --help, -h : Show this help
  -- : Do not treat any remaining argument as a switch (at this level)
 Multiple single-letter switches can be combined after one `-'; for
  example: `-h-' is the same as `-h --'
```

You can then simply run: 
`racket prunedocker.rkt -u youruser -p yourpass -r a_repo -k 20`

Or for a convinient run wihtouth having to setup Racket or generate a full executable, just use this docker image like this:

`docker run paulosuzart/prunedocker -u youruser -p yourpass -r a_repo -k 20`

## author
paulosuzart

## license
Apache 2.0

