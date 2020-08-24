(import (scheme base)
        (srfi srfi-1))

(define (form->ast form)
  (case (car form)
    ((define)
     (if (pair? (cadr form))
         (make-ast-define (caadr form)
                          (make-ast-lambda (cdadr form)
                                           (map object->ast (cddr form))))
         (make-ast-define (cadr form) (object->ast (cddr form)))))
    ((set!) (make-ast-set (second form) (object->ast (third form))))
    ((lambda) (make-ast-lambda (second form) (map object->ast (cddr form))))
    ((if) (make-ast-if (second form) (object->ast (third form))
                       (object->ast (fourth form))))
    ((quote) (make-ast-quote (second form)))
    (else (make-ast-call (object->ast (car form))
                         (map object->ast (cdr form))))))


(define (object->ast object)
  (cond
   ((list? object) (form->ast object))
   ((symbol? object) (make-ast-ref object))
   (else (make-ast-literal object))))

;; #f if no valid unquote occurs in form
(define (never-unquoted? form)
  (cond
   ((not (pair? form)) #t)
   ((eq? (car form) 'unquote) #f)
   ((eq? (car form) 'unquote-splicing) #f)
   ((or (eq? (car form) 'quasiquote)
        (eq? (car form) 'quote))
    #t)
   (else (and (never-unquoted? (car form))
              (never-unquoted? (cdr form))))))

;; expands a quasiquoted value
(define (expand-1-quasiquote form)
  (cond ; TODO check tail for no more unquotes
   ((or (not (pair? form))
        (never-unquoted? form))
    `(quote ,form))
   ((eq? (car form) 'unquote)
    (expand-quasiquotes (cadr form)))
   ((and
     (list? (cadr form))
     (eq? (caadr form) 'unquote-splicing))
    `(append (list ,(expand-1-quasiquote (car form)))
            (list ,@(expand-quasiquotes (cadadr form)))))
   (else
    `(cons ,(expand-1-quasiquote (car form))
           ,(expand-1-quasiquote (cdr form))))))

;; expands quasiquote into cons and regular quote
(define (expand-quasiquotes form)
  (cond
   ((not (pair? form)) form)
   ((eq? (car form) 'quasiquote)
    (expand-1-quasiquote (cadr form)))
   (else (map expand-quasiquotes form))))


(define (pipeline val fns)
  (if (null? fns)
      val
      (pipeline ((car fns) val) (cdr fns))))

(define (-> val . fns)
  (pipeline val fns))

(define (frontend form)
  (-> form
      expand-quasiquotes
      object->ast))