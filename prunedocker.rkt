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

(define (fetch-tags user repo token page)
  (let* ([uri (string->url (format "https://hub.docker.com/v2/repositories/~a/~a/tags/?page=~a" user repo page))]
         [in (get-pure-port uri (with-auth-header token))]
         [tags-result (read-json in)])
    (displayln (format "https://hub.docker.com/v2/repositories/~a/~a/tags/page=~a" user repo page))
    tags-result))

(define (delete-tag user repo tag token)
  (let* ([uri (string->url (format "https://hub.docker.com/v2/repositories/~a/~a/tags/~a/" user repo tag))]
         [in (delete-pure-port uri (with-auth-header token))]
         [delete-result (read-json in)])
  delete-result))
 

(define tags
  (case-lambda
    [(user repo token) (tags user repo token 1)]
    [(user repo token page)
     (let ([tag-result (fetch-tags user repo token page)])
       (stream-append (hash-ref tag-result 'results)
                      (if (equal? (hash-ref tag-result 'next) 'null)
                          empty-stream
                          (tags user repo token (add1 page)))))]))

(define (prune user repo tag-names token)
  (stream-for-each
   (λ [name]
     (displayln (format "Prunning tag ~a" name))
     (delete-tag user repo name token))
   tag-names))

(define main
  (command-line
   #:program "Prune Docker Hub"
   #:once-each
   [("-u" "--user") u "Dockerhub Login"
                    (username u)]
   [("-p" "--passowrd") p "Dockerhub password"
                        (password p)]
   [("-r" "--repo") r "Dockerhub repository"
                    (repository r)]
   [("-k" "--keep") k "Keeps k tags in the repo. Will delete the remining older tags"
                    (keep (string->number k))]))

(when (or (equal? "" (username))
        (equal? "" (password))
        (equal? "" (repository))
        (equal? -1 (keep)))
  (exit 1))
    

(let* ([token (authenticate (username) (password))]
       [tags-stream (tags (username) (repository) token)]
       [tag-names (stream-map (λ [t] (hash-ref t 'name)) tags-stream)])
  (when (< (keep) (stream-length tag-names))
    (prune (username) (repository) (stream-tail tag-names (keep)) token)))




