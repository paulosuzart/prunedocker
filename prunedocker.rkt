#lang racket

(require net/http-client)
(require net/url)
(require net/uri-codec)
(require racket/cmdline)
(require json)

(define username (make-parameter ""))
(define password (make-parameter ""))
(define repository (make-parameter ""))
(define keep (make-parameter -1))

(define base-headers (list "Content-Type: application/json"))

(define (auth-header token)
  (list (format "Authorization: JWT ~a" token)))

(define (with-auth-header token)
  (append base-headers (auth-header token)))

(define (authenticate user pass)
  (let* ([uri (string->url "https://hub.docker.com/v2/users/login")]
         [auth-payload (hasheq 'username user 'password pass)]
         [in (post-pure-port uri (jsexpr->bytes auth-payload) base-headers)]
         [token (hash-ref (read-json in) 'token)])
    token))

(define (fetch-tags user repo token page-url)
  (let* ([uri (string->url page-url)]
         [in (get-pure-port uri (with-auth-header token))]
         [tags-result (read-json in)])
    (displayln page-url)
    tags-result))

(define (delete-tag user repo tag token)
  (let* ([uri (string->url (format "https://hub.docker.com/v2/repositories/~a/~a/tags/~a/" user repo tag))]
         [in (delete-pure-port uri (with-auth-header token))]
         [delete-result (read-json in)])
    delete-result))
 

(define tags
  (case-lambda
    [(user repo token) (tags user repo token (format "https://hub.docker.com/v2/repositories/~a/~a/tags/" user repo))]
    [(user repo token page)
     (if (equal? 'null page)
         empty-stream
         (let* ([tag-result (fetch-tags user repo token page)]
                [results (hash-ref tag-result 'results)])
           (stream-cons (first results) 
                          (stream-append
                            (rest results)
                            (tags user repo token (hash-ref tag-result 'next))))))]))

(define (prune user repo tags-stream keep token)
  (define tags-to-delete 
    (for/stream ([tag tags-stream]
                 [index (in-naturals 1)]
                 #:when (> index keep))
      tag))
  (stream-for-each
   (λ [tag]
     (displayln (format "Prunning tag ~a" (hash-ref tag 'name)))
     (delete-tag user repo (hash-ref tag 'name) token))
   tags-to-delete))
            

(define main
  (command-line
   #:program "Prune DockerHub"
   #:once-each
   [("-u" "--user") u "Dockerhub Login"
                    (username u)]
   [("-p" "--password") p "DockerHub password"
                        (password p)]
   [("-r" "--repo") r "Dockerhub repository"
                    (repository r)]
   [("-k" "--keep") k "Keeps k tags in the repo. Will delete the remaining older tags"
                    (keep (string->number k))]))

(when (or (equal? "" (username))
          (equal? "" (password))
          (equal? "" (repository))
          (equal? -1 (keep)))
  (display "Please run: racket prunedocker.rkt --help to see the available run options")
  (exit 1))
    

(let* ([token (authenticate (username) (password))]
       [tags-stream (tags (username) (repository) token)])
  (prune (username) (repository) (stream->list tags-stream) (keep) token))




