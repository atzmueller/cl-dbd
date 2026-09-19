(defpackage #:cl-dbd-tests
  (:use #:cl #:fiveam))

(in-package #:cl-dbd-tests)

(def-suite cl-dbd-suite :description "Tests for the cl-dbd Datalog engine.")

(in-suite cl-dbd-suite)


(defmacro with-cleaned-db (&body body)
  "Reset the Datalog database to an empty state before running BODY."
  `(progn (cl-dbd:clear-dl-db) ,@body))


(test ground-query-succeeds-against-ground-fact
  "A ground query matching an identical ground fact must return non-nil.
   Unifying equal ground terms yields '(); (and '() ...) short-circuits
   because '() is false in CL, so no result is ever collected."
  (with-cleaned-db
    (cl-dbd:<- (parent alice bob))
    (let ((result (cl-dbd:?- (parent alice bob))))
      (is (not (null result))
          "Ground query (parent alice bob) should succeed; got NIL"))))


(test resolve-body-returns-singleton-list-for-ground-match
  "resolve-body must return '(()) - a list holding one empty binding set -
   when a ground body literal unifies with a ground fact."
  (with-cleaned-db
    (cl-dbd:<- (foo bar))
    (let ((result (cl-dbd:resolve-body '((foo bar)) '())))
      (is (equal result '(()))
          "resolve-body returned ~S; expected '(()) for a ground match"
          result))))


(test propositional-rule-derives-its-head
  "The rule (b) :- (a) must add (b) to the database when (a) is a fact."
  (with-cleaned-db
    (cl-dbd:<- (a))
    (cl-dbd:<- (b) (a))
    (cl-dbd:forward-chain)
    (is (cl-dbd:fact-exists-p '(b))
        "(b) should be derived by (b :- a) but is absent")))


(test each-solution-is-a-complete-binding-alist
  "Two matching facts against a two-variable query should yield a list of
   two alists, each containing bindings for both variables."
  (with-cleaned-db
    (cl-dbd:<- (parent alice bob))
    (cl-dbd:<- (parent carol dave))
    (let ((results (cl-dbd:?- (parent ?x ?y))))
      (is (= 2 (length results))
          "Expected 2 grouped solutions, got ~A: ~S"
          (length results) results)
      (is (every #'listp results)
          "Each solution must be an alist, not a raw cons pair. Got: ~S"
          results)
      (is (every (lambda (sol)
                   (and (assoc '?x sol) (assoc '?y sol)))
                 results)
          "Every solution must bind both ?x and ?y. Got: ~S" results))))


(test solutions-from-distinct-facts-are-separable
  "With two facts matching a two-variable query, it must be possible to
   pair each ?k with its corresponding ?v."
  (with-cleaned-db
    (cl-dbd:<- (kv a 1))
    (cl-dbd:<- (kv b 2))
    (let ((results (cl-dbd:?- (kv ?k ?v))))
      (is (= 2 (length results))
          "Expected 2 grouped solutions, got ~A: ~S"
          (length results) results)
      (is (every (lambda (sol)
                   (and (assoc '?k sol) (assoc '?v sol)))
                 results)
          "Every solution must carry both ?k and ?v. Got: ~S" results))))


(test negated-query-succeeds-when-fact-is-absent
  "(?- (not (parent alice carol))) must return non-nil because that fact
   is absent."
  (with-cleaned-db
    (cl-dbd:<- (parent alice bob))   ; carol is absent
    (let ((result (cl-dbd:?- (not (parent alice carol)))))
      (is (not (null result))
          "Negated query for an absent fact should succeed; got NIL"))))


(test transitive-chain-resolves-to-ground-value
  "With bindings ((?x . ?y) (?y . alice)), applying to ?x must yield alice."
  (let* ((bindings '((?x . ?y) (?y . alice)))
         (result   (cl-dbd:apply-substitutions '?x bindings)))
    (is (equal result 'alice)
        "Expected alice via ?x->?y->alice; got ~S" result)))


(test variable-bound-to-nil-returns-nil
  "If ?x is bound to NIL the result must be NIL."
  (let* ((bindings '((?x . nil)))
         (result   (cl-dbd:apply-substitutions '?x bindings)))
    (is (null result)
        "?x bound to NIL should yield NIL, not the symbol ?x; got ~S"
        result)))


(test chained-variable-inside-compound-term
  "Transitive resolution must propagate inside compound terms.
   (parent ?x bob) with ((?x . ?y) (?y . alice)) must become
   (parent alice bob)"
  (let* ((bindings '((?x . ?y) (?y . alice)))
         (result   (cl-dbd:apply-substitutions '(parent ?x bob) bindings)))
    (is (equal result '(parent alice bob))
        "Expected (parent alice bob); got ~S" result)))


(test naf-incorrectly-succeeds-when-matching-ground-fact-exists
  "resolve-body on (not (parent ?x alice)) with empty bindings must return
   NIL when (parent bob alice) is in the database -- some X satisfies
   (parent X alice)."
  (with-cleaned-db
    (cl-dbd:<- (parent bob alice))
    (let ((result (cl-dbd:resolve-body '((not (parent ?x alice))) '())))
      (is (null result)
          "NAF with free ?x should fail when (parent bob alice) exists; got ~S"
          result))))


(test naf-correctly-fails-when-variable-is-pre-bound
  "Contrast: when ?x is already bound to bob in the incoming bindings,
   apply-substitutions grounds the literal to (parent bob alice) before
   the NAF check.  fact-exists-p then correctly detects the fact."
  (with-cleaned-db
    (cl-dbd:<- (parent bob alice))
    (let ((result (cl-dbd:resolve-body '((not (parent ?x alice)))
                                         '((?x . bob)))))
      (is (null result)
          "NAF (not (parent bob alice)) with ?x=bob pre-bound should fail"))))
